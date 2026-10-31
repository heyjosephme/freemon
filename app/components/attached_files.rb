# frozen_string_literal: true

# Lists a record's saved attachments inside its form as checked checkboxes.
# Assigning to a has_many_attached replaces the whole collection, so every file
# to keep must be resubmitted by signed_id; unchecking one removes it on save.
class Components::AttachedFiles < Components::Base
  def initialize(attachments:, field_name:)
    # Uploads from a failed submission were never saved and have no signed_id yet.
    @attachments = attachments.select { |attachment| attachment.blob.persisted? }
    @field_name = field_name
  end

  def view_template
    return if @attachments.empty?

    div(class: "mb-4") do
      p(class: "text-sm font-medium text-gray-700 mb-2") { "添付済みファイル:" }
      @attachments.each do |attachment|
        label(class: "flex items-center gap-2 text-sm text-gray-600 mb-1") do
          input(type: "checkbox", name: @field_name, value: attachment.signed_id, checked: true,
                class: "h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-600")
          span { attachment.filename.to_s }
          span(class: "text-gray-400") { "(#{ActiveSupport::NumberHelper.number_to_human_size(attachment.byte_size)})" }
        end
      end
      p(class: "mt-1 text-sm text-gray-500") { "チェックを外して保存すると削除されます。" }
    end
  end
end
