require 'sanitize'
require_dependency 'mail_handler'

module MailHandlerInlineImagesPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)
    base.class_eval do
      alias_method_chain :add_attachments, :remove_inline_images
      alias_method_chain :cleaned_up_text_body, :inline_images
    end
  end

  module InstanceMethods
    def add_attachments_with_remove_inline_images(obj)
      truncated = decoded_html.split(INVISIBLE_EMAIL_HEADER_DECODED, 2)[1]
      if truncated
        truncated.scan(FIND_IMG_SRC_PATTERN) do |_, src, _|
          src.match(/^cid:(.+)/) do |m|
            remove_part_with_cid(email.parts, m[1])
          end
        end
      end
      add_attachments_without_remove_inline_images obj
    end

    def decoded_html
      return @decoded_html unless @decoded_html.nil?
      # decodedHtml = email.html_part.body.decoded.force_encoding("utf-8")
      @decoded_html = decode_part_body(email.html_part)
    end

    def cleaned_up_text_body_with_inline_images
      return @cleaned_up_text_body unless @cleaned_up_text_body.nil?

      parts = if (html_parts = email.all_parts.select {|p| p.mime_type == 'text/html'}).present?
                html_parts
              elsif (text_parts = email.all_parts.select {|p| p.mime_type == 'text/plain'}).present?
                text_parts
              else
                [email]
              end

      parts.reject! do |part|
        part.header[:content_disposition].try(:disposition_type) == 'attachment'
      end

      plain_text_body = parts.map { |p| decode_part_body(p) }.join("\r\n")

      # strip html tags and remove doctype directive
      if parts.any? {|p| p.mime_type == 'text/html'}
        plain_text_body.gsub!(FIND_IMG_SRC_PATTERN) do
          filename = nil
          $2.match(/^cid:(.+)/) do |m|
            filename = email.all_parts.find {|p| p.cid == m[1]}.filename
          end
          " !#{filename}! "
        end

        redmine_from = Setting.mail_from
        redmine_email_seen = false

        plain_text_body = Sanitize.fragment(plain_text_body,
          :elements => %w[  ], # do not allow any elements
          :attributes => {
              'a'          => %w[href],
          },
          :protocols => {
              'a'          => {'href' => ['ftp', 'http', 'https', 'mailto', :relative]},
          },
          :whitespace_elements => {
              'br'  => { :before => "\n", :after => "" },
              'p'   => { :before => "\n", :after => "" },
              'li'   => { :before => "", :after => "\n" },
              'ol'   => { :before => "", :after => "\n" },
          },
          :transformers => [
              lambda do |env|
                return unless env[:node_name] == 'style' # total delete for style element (bug with outlook output)
                    # || env[:node_name] == 'blockquote' # remove contents of quotes
                node = env[:node]
                node.unlink
              end,

              lambda do |env|
                if redmine_email_seen
                  node = env[:node]
                  node.unlink
                else
                  node = env[:node]
                  if node.text?
                    if node.to_s.match(redmine_from)
                      redmine_email_seen = true
                    end
                  end
                end
              end,
          ],
        )
        plain_text_body = cleanup_body(plain_text_body << "\n") # \n fixes cleanup bug
        plain_text_body.gsub!(/^[ \t]+(![^!]+!)/, '\1') # fix for images
      end
      @cleaned_up_text_body = plain_text_body.strip
    end


    private

    def remove_part_with_cid(parts, cid_to_remove)
      parts.select! do |part|
        keep = part.cid != cid_to_remove
        remove_part_with_cid(part.parts, cid_to_remove) if keep
        keep
      end
    end

    def decode_part_body(p)
      body_charset = Mail::RubyVer.respond_to?(:pick_encoding) ?
          Mail::RubyVer.pick_encoding(email.html_part.charset).to_s : p.charset
      Redmine::CodesetUtil.to_utf8(p.body.decoded, body_charset)
    end
  end
end

MailHandler.send(:include, MailHandlerInlineImagesPatch)

