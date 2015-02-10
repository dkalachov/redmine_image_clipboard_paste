require 'redmine'
require 'issue_hooks'

# Init constants
require 'htmlentities'
coder = HTMLEntities.new
INVISIBLE_EMAIL_HEADER = "&#8203;" * 20
INVISIBLE_EMAIL_HEADER_DECODED = coder.decode(INVISIBLE_EMAIL_HEADER)
FIND_IMG_SRC_PATTERN = /(<img[^>]+src=")([^"]+)("[^>]*>)/

# Email patches
require 'email_send_patch'
require 'email_receive_patch'
require 'message_filename_patch'

Redmine::Plugin.register :redmine_image_clipboard_paste do
  name 'Image Clipboard Paste'
  author 'credativ Ltd'
  description 'Allow pasting an image from the clipboard into the comment box on the form and show them in email.'
  version '1.1.0'
  requires_redmine :version_or_higher => '2.3.0'
end

