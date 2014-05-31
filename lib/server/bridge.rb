require File.expand_path(File.dirname(__FILE__)) + "/remote_debugger.rb"

module Server

class Bridge
  attr_accessor :debugger
  attr_accessor :current_using
  attr_accessor :current_selector

  def initialize(websocket_uri)
    @debugger = Server::RemoteDebugger.new(websocket_uri)
  end

  def goto(url)
    @debugger.page_navigate(url)
  end

  def load_atoms
    result = self.eval_js("typeof(goog) === 'undefined' && typeof(bot) === 'undefined'")
    if result == false
      return
    end

    atoms_file = File.expand_path(File.dirname(__FILE__)) + "/atoms.js"
    atoms_data = File.open(atoms_file, "r") {|f| f.read }
    #$stdout.puts "\n\n****** Atoms: #{atoms_file} \n\n #{ atoms_data }\n\n"
    self.eval_js(atoms_data)
    atoms_data = nil
    atoms_file = nil
  end

  def elements(using, value)
    elements = []
    self.current_selector = value
    self.current_using    = using
    case using
    when "css selector"
      elements = elements_by_css(value)
    when "xpath"
      elements = elements_by_xpath(value)
    end
    elements
  end

  def child_elements(element_id, using, value)
    current_elements_count = elements(self.current_selector, self.current_using).size
    if using == "css selector"
      js = %Q{
        var element = __elements[#{ element_id }];
        var elements = element.querySelectorAll("#{ value }");
        var nodes = [];
        for(var i=0; i<elements.length; i++) {
          nodes.push(elements[i]);
        }

        var new_elements = [];
        for(var i=0; i<__elements.length; i++) {
          new_elements.push(__elements[i]);
        }
        __elements = new_elements;

        for(var i=0; i<nodes.length; i++) {
          __elements.push(nodes[i]);
        }
        nodes.length;
      }.strip
    elsif using == "xpath"
      js = %Q{
        var element = __elements[#{ element_id }];
        var elements = document.evaluate("#{ value }", element, null, XPathResult.ANY_TYPE, null);
        var nodes = [];
        while(item = elements.iterateNext()) {
          nodes.push(item);
        }

        var new_elements = [];
        for(var i=0; i<__elements.length; i++) {
          new_elements.push(__elements[i]);
        }
        __elements = new_elements;

        for(var i=0; i<nodes.length; i++) {
          __elements.push(nodes[i]);
        }
        nodes.length;
      }.strip
    end
    # $stdout.puts "\n\n", js, "\n\n"
    result = @debugger.runtime_evaluate(js)

    begin
    json = JSON.parse(result.first)
    rescue Exception, ArgumentError => e
      $stdout.puts "***** ERROR RESULT: #{ result }\n\n"
      $stdout.puts "***** ERROR RESULT: #{ e }\n\n"
      json = {}
    end
    json_result = json['result']
    # $stdout.puts "*** JSON Result: #{ json_result }\n\n"

    elements_count = element_id.to_i
    elements = []
    if json_result && json_result['wasThrown'] == false && json_result['result']['type'] == "number"
      elements_count = json_result['result']['value']
      elements = current_elements_count.upto((current_elements_count + elements_count) - 1).map {|idx|
        {"ELEMENT" => idx.to_s}
      }
    end
    # $stdout.puts "\n\n****** ELEMENTS: #{ elements }\n\n"
    elements
  end


  def elements_by_css(value)
    selector = value
    result = @debugger.runtime_evaluate(%Q{__elements = document.querySelectorAll("#{ selector }"); __elements.length;})
    json = JSON.parse(result.first)
    json_result = json['result']
    elements_count = 0
    if json_result['wasThrown'] == false && json_result['result']['type'] == "number"
      elements_count = json_result['result']['value']
    end
    elements = 0.upto(elements_count - 1).map {|idx| {"ELEMENT" => idx.to_s} }
  end

  def elements_by_xpath(value)
    # {"using":"xpath","value":".//input[./@type = 'submit' or ./@type = 'reset' or ./@type = 'image' or ./@type = 'button'][((./@id = 'Search' or ./@value = 'Search') or ./@title = 'Search')] | .//input[./@type = 'image'][./@alt = 'Search'] | .//button[(((./@id = 'Search' or ./@value = 'Search') or normalize-space(string(.)) = 'Search') or ./@title = 'Search')] | .//input[./@type = 'image'][./@alt = 'Search']"}
    selector = value
    js = %Q{
      var elements = document.evaluate("#{ value }", document, null, XPathResult.ANY_TYPE, null);
      __elements = [];
      while(item = elements.iterateNext()) {
        __elements.push(item);
      }
      __elements.length;
    }

    result = @debugger.runtime_evaluate(js)
    json = JSON.parse(result.first)
    json_result = json['result']
    elements_count = 0
    if json_result['wasThrown'] == false && json_result['result']['type'] == "number"
      elements_count = json_result['result']['value']
    end
    elements = 0.upto(elements_count - 1).map {|idx| {"ELEMENT" => idx.to_s} }
  end

  def enabled?(element_id)
    js = %Q{
      var is_enabled = false;
      if(__elements[#{ element_id }]) {
        is_enabled = (__elements[#{ element_id }].disabled == false);
      }
      is_enabled;
    }
    result = @debugger.runtime_evaluate(js)
    result = result.first
    json = JSON.parse(result)
    $stdout.puts json.inspect, "\n\n\n\n"

    result_value = nil
    json_result = json['result']
    if json_result['wasThrown'] == false && json_result['result']['type'] == "boolean"
      result_value = json_result['result']['value']
    end
    result_value
  end

  def displayed?(element_id)
    self.load_atoms
    js = %Q{bot.dom.isShown(__elements[#{ element_id }])}
    result_value = self.eval_js(js)
  end

  def text(element_id)
    result = @debugger.runtime_evaluate("__elements[#{ element_id }].innerText")
    result = result.first
    json = JSON.parse(result)
    json_result = json['result']
    result_value = ""
    if json_result['wasThrown'] == false && json_result['result']['type'] == "string"
      result_value = json_result['result']['value']
    end
    result_value
  end

  def name(element_id)
    result = @debugger.runtime_evaluate("__elements[#{ element_id }].tagName")
    result = result.first
    json = JSON.parse(result)
    json_result = json['result']
    result_value = ""
    if json_result['wasThrown'] == false && json_result['result']['type'] == "string"
      result_value = json_result['result']['value']
    end
    result_value
  end

  def attribute(element_id, attr_name)
    result = @debugger.runtime_evaluate("__elements[#{ element_id }].#{attr_name.strip}")
    result = result.first
    json = JSON.parse(result)
    json_result = json['result']
    result_value = nil
    if json_result['wasThrown'] == false && json_result['result']['type'] == "string"
      result_value = json_result['result']['value']
    end
    result_value
  end

  def eval_js(js)
    result = @debugger.runtime_evaluate(js)
    result = result.first
    json = JSON.parse(result)
    json_result = json['result']
    #$stdout.puts "\n\n#{ json_result }\n\n"
    result_value = nil
    if json_result && json_result['wasThrown'] == false && json_result['result']
      result_value = json_result['result']['value']
    end
    result_value
  end

  def click(element_id)
    load_atoms
    js = %Q{ bot.action.click(__elements[#{ element_id }]); }
    result = @debugger.runtime_evaluate(js)
    result = result.first
  end

  def execute_json(json)
    script = json['script']
    args   = json['args']
    js = %Q{
      var _test = function(){
        #{script};
      };
    }
    args.map {|element|
      element_id = element['ELEMENT']
      js << "_test(__elements[#{ element_id }]);\n"
    }
    if args.size == 0
      js << "_test();\n"
    end
    result = @debugger.runtime_evaluate(js)
    result = result.first
    json = JSON.parse(result)
    json_result = json['result']
    result_value = nil
    if json_result && json_result['wasThrown'] == false && json_result['result']['type'] != "undefined"
      result_value = json_result['result']['value']
    end
    result_value
  end

  def set_value(element_id, json)
    load_atoms
    strvalue = json['value'].first

    js = %Q{
      var text = "#{ strvalue }";
      bot.action.type(__elements[#{ element_id }], text);
    }

    # keydown, keypress, and keyup events
    result = @debugger.runtime_evaluate(js)
    sleep (100.0 * strvalue.size.to_i ) / 1000.0
  end

  def network_traffic
    @debugger.network_traffic
  end

  def http_headers(headers)
    @debugger.set_extra_http_headers(headers)
  end

  def cookie
    result = @debugger.page_get_cookies
    result = result.first
    json = JSON.parse(result)
    cookies = []
    if json_result = json['result']
      cookies = json_result['cookies']
    end
    cookies
  end

  def delete_cookie(name, url=nil)
    if url.nil?
      url = self.current_url
    end
    result = @debugger.page_delete_cookie(name, url)
    result = result.first
    json = JSON.parse(result)

    value = false
    if json_result = json['result']
      if json_result.keys.size == 0
        value = true
      end
    end
    value
  end

  def current_url
    js = "window.location.href"
    result = @debugger.runtime_evaluate(js)
    result = result.first
    json = JSON.parse(result)
    json_result = json['result']
    result_value = nil
    if json_result && json_result['wasThrown'] == false && json_result['result']['type'] != "undefined"
      result_value = json_result['result']['value']
    end
    result_value
  end

  def page_reload
    result = @debugger.page_reload
    result = result.first
    json = JSON.parse(result)
    value = false
    if json_result = json['result']
      if json_result.keys.size == 0
        value = true
      end
    end
    value
  end

  def screenshot
    result = @debugger.screenshot
    $stdout.puts "***** SCREENSHOT\n\n#{ result }\n\n"

    result = result.first
    json = JSON.parse(result)
    json_result = json['result']
    result_value = nil
    if json_result && json_result['wasThrown'] == false && json_result['result']['type'] != "undefined"
      result_value = json_result['result']['value']
    end
    result_value
  end
end

end
