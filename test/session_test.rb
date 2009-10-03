require 'test_helper'

class SessionTest < Test::Unit::TestCase
  def setup
    @config = Trample::Configuration.new do
      iterations 2
      get "http://google.com/"
      get "http://amazon.com/"
      post "http://google.com/"
    end
    @session = Trample::Session.new(@config)
  end

  context "Starting a trample session" do
    setup do
      @session.trample
    end

    before_should "visit the pages iterations times each" do
      mock_get("http://google.com/", :times => 2)
      mock_get("http://amazon.com/", :times => 2)
      mock_post("http://google.com/", :times => 2)
    end
  end

  context "Visiting a page" do
    setup do
      stub(@session).time { 1.4 }
      stub(@session).last_response do
        response = RestClient::Response.new("", stub!)
        stub(response).cookies { {} }
        stub(response).code { 200 }
      end
      @session.trample
    end

    should "record the length of time it took to visit that page" do
      assert_equal [1.4, 1.4, 1.4, 1.4, 1.4, 1.4], @session.response_times
    end
  end

  context "If a page responds with a cookie" do
    should "pass that cookie on to the next page" do
      stub(RestClient).get(anything, anything) do
        response = RestClient::Response.new("", stub!)
        stub(response).cookies { {"xyz" => "abc"} }
        stub(response).code { 200 }
      end

      @config = Trample::Configuration.new do
        iterations 2
        get "http://amazon.com/"
      end

      @session = Trample::Session.new(@config)
      @session.trample

      assert_received(RestClient) { |c| c.get("http://amazon.com/", :cookies => {"xyz" => "abc"}) }
    end
  end

  context "A session with login" do
    # TODO: the order of the requests isn't being tested here. not 
    # sure if it's possible with rr
    should "hit the login once at the beginning of the session" do
      @config = Trample::Configuration.new do
        iterations 2
        login do
          post "http://google.com/login" do
            {:user => "xyz", :password => "swordfish"}
          end
        end
        get "http://google.com/"
      end
      stub_get(anything, :times => 2)
      mock_post("http://google.com/login", :payload => {:user => "xyz", :password => "swordfish"}, :times => 1)
      Trample::Session.new(@config).trample
    end
  end

  context "Testing a site with forgery protection enabled" do
    should "pass the authenticity token in the login POST params" do
      @config = Trample::Configuration.new do
        iterations 1
        login do
          get "http://google.com"
          post "http://google.com/login" do
            {:user => "xyz", :password => "swordfish"}
          end
        end
      end
      stub(RestClient).get(anything, anything) do
        response = "<input type='hidden' value='abc' name='authenticity_token'/>"
        stub(response).cookies { {} }
        stub(response).code { 200 }
      end
      mock_post("http://google.com/login", :payload => {:user => "xyz", :password => "swordfish", :authenticity_token => 'abc'}, :times => 1)
      Trample::Session.new(@config).trample
    end
  end
end

