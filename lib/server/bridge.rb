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
    load_atoms
    current_elements_count = eval_js("__elements.length")

    if using == "css selector"
      eval_js %Q{ var child_elements = bot.locators.findElements({ css: "#{ value }" }, __elements[#{ element_id }]); }
    elsif using == "xpath"
      eval_js %Q{ var child_elements = bot.locators.findElements({ xpath: "#{ value }" }, __elements[#{ element_id }]); }
    end

    js = %Q{
      var new_elements = [];

      for(var i=0; i<__elements.length; i++) {
        new_elements.push(__elements[i]);
      }
      __elements = new_elements;
      new_elements = null;

      for(var i=0; i<child_elements.length; i++) {
        __elements.push(child_elements[i]);
      }
      child_elements.length;
    }.strip

    elements_count = eval_js(js)

    elements = current_elements_count.upto((current_elements_count + elements_count) - 1).map {|idx|
      {"ELEMENT" => idx.to_s}
    }
  end


  def elements_by_css(value)
    load_atoms
    js = %Q{ __elements = bot.locators.findElements({ css: "#{ value }" }); __elements.length; }
    elements_count = eval_js(js)
    elements = 0.upto(elements_count - 1).map {|idx| {"ELEMENT" => idx.to_s} }
  end

  def elements_by_xpath(value)
    load_atoms
    js = %Q{ __elements = bot.locators.findElements({ xpath: "#{ value }" }); __elements.length; }
    elements_count = eval_js(js)
    elements = 0.upto(elements_count - 1).map {|idx| {"ELEMENT" => idx.to_s} }
  end

  def enabled?(element_id)
    load_atoms
    eval_js %Q{ bot.dom.isEnabled(__elements[#{ element_id }]) }
  end

  def displayed?(element_id)
    load_atoms
    eval_js %Q{ bot.dom.isShown(__elements[#{ element_id }]) }
  end

  def text(element_id)
    load_atoms
    eval_js %Q{ bot.dom.getVisibleText(__elements[#{ element_id }]) }
  end

  def name(element_id)
    eval_js %Q{ __elements[#{ element_id }].tagName }
  end

  def attribute(element_id, attr_name)
    load_atoms
    eval_js %Q{ bot.dom.getAttribute(__elements[#{ element_id }], "#{ attr_name }") }
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
    eval_js %Q{ bot.action.click(__elements[#{ element_id }]); }
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
    eval_js js
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

  def title
    eval_js "document.title"
  end

  def current_url
    eval_js "window.location.href"
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
