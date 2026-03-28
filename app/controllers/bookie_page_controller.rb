class BookiePageController < ApplicationController
  def index
    render html: "".html_safe, layout: "application"
  end
end
