require 'ostruct'
class OpenStruct2 < OpenStruct
  require 'json'
  def to_json
    return self.to_h.to_json
  end
end

