require "test_helper"

class SheetsControllerTest < ActionDispatch::IntegrationTest
  test "index requires authentication" do
    get sheets_url
    assert_redirected_to root_url
  end
end
