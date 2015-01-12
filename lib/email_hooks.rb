class InlineImagesEmailInterceptor
  def self.delivering_email(message)
    text_part = message.text_part
    html_part = message.html_part

    if html_part
      related = Mail::Part.new
      related.content_type = 'multipart/related'
      related.add_part html_part
      html_part.body = html_part.body.to_s.gsub(/(<img src=")([^"]+)(")/) do
        image_url = $2
        attachment_url = image_url
        attachment_object = Attachment.where(:filename => File.basename(image_url)).first
        if attachment_object
          # Use CIDs
          image_name = attachment_object.filename
          related.attachments.inline[image_name] = File.read(attachment_object.diskfile)
          attachment_url = related.attachments[image_name].url

          # Alternatively use Base64
          # attachment_url = "data:#{Redmine::MimeType.of(attachment_object.diskfile)};base64,#{Base64.encode64(open(attachment_object.diskfile) { |io| io.read })}"
        end

        $1 << attachment_url << $3
      end

      message.parts.clear
      message.parts << text_part
      message.parts << related
    end
  end
end

