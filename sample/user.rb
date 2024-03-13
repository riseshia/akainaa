# frozen_string_literal: true

require_relative './theme'

module User
  module_function

  def find(id)
    {
      id: id,
      theme: Theme.find_by(user_id: id),
    }
  end
end
