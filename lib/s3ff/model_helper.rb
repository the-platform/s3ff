module S3FF
  module ModelHelper
    def download_from_direct_url_with_delay(attr_name, nil_direct_url_after_save: false)
      if self.respond_to?(:delay)
        has_db_column = self.column_names.include?("#{attr_name}_direct_url") rescue false

        if has_db_column
          self.class_eval <<-EOM

            after_save :delay_s3ff_download_direct_url, if: -> { #{attr_name}_direct_url.present? && #{attr_name}_direct_url_changed? }

          EOM
        else
          self.class_eval <<-EOM

            def #{attr_name}_direct_url
              @#{attr_name}_direct_url
            end

            def #{attr_name}_direct_url=(val)
              #{"return if val.blank?" if nil_direct_url_after_save}
              self.updated_at = Time.now if val != @#{attr_name}_direct_url
              @#{attr_name}_direct_url = val
            end

            after_save :delay_s3ff_download_direct_url, if: proc { #{attr_name}_direct_url.present? }

          EOM
        end

        self.class_eval <<-EOM

          def delay_s3ff_download_direct_url
            self.class.delay.s3ff_download_direct_url(id, #{attr_name}_direct_url)
          end

          def self.s3ff_download_direct_url(instance_id, #{attr_name}_direct_url)
            open(#{attr_name}_direct_url, ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE) do |file|
              find(instance_id).update(
                #{attr_name}: file,
                #{attr_name}_file_name: File.basename(#{attr_name}_direct_url),
                #{"#{attr_name}_direct_url: nil," if nil_direct_url_after_save}
              )
            end
          end
        EOM
      elsif self.respond_to?(:handle_asynchronously)

        # handle_asynchronously requires db column anyways
        self.class_eval <<-EOM
          after_save :s3ff_download_direct_url, if: -> { #{attr_name}_direct_url.present? && #{attr_name}_direct_url_changed? }

          def s3ff_download_direct_url
            open(#{attr_name}_direct_url, ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE) do |file|
              update(
                #{attr_name}: file,
                #{attr_name}_file_name: File.basename(#{attr_name}_direct_url),
                #{"#{attr_name}_direct_url: nil," if nil_direct_url_after_save}
              )
            end
          end

          handle_asynchronously :s3ff_download_direct_url
        EOM
      else
        raise NotImplementedError('download_from_direct_url_with_delay only supports delayed_job or sidekiq delayed extension')
      end
    end
  end
end
