class LineItem < ActiveRecord::Base
  belongs_to :order

  before_save :decode_html_entities

  include ActionView::Helpers::SanitizeHelper

  private

  def decode_html_entities
    for column in LineItem.content_columns
      if column.type == :string || column.type == :text
        if !self[column.name].nil?
          self[column.name] = CGI.unescapeHTML(strip_tags(self[column.name]))
        end
      end
    end
  end
end
