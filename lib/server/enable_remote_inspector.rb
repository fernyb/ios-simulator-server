module Server
  class EnableRemoteInspector
    def self.lldb cmd
      $lldb ||= IO.popen("lldb", "w")
      $lldb.puts cmd
      $lldb.flush
      sleep 3
    end

    def self.enable!
      #
      # Dependencies:
      #
      # brew install ios-webkit-debug-proxy
      # brew install lsof
      # lldb should come from the XCode Developer Tools
      #

      # out = `ps ax | grep "Applications/iPhone Simulator.app" | grep -v grep | awk '{ print $1 }'`.to_s
      # if out =~ /^[0-9]+$/
      #   `kill -9 #{out}`
      #   sleep 5
      # end

      # tell application "System Events" to tell process "iPhone Simulator"
      #   tell application "iPhone Simulator" to activate
      #   delay 1

      #   tell window "iOS Simulator - iPad Retina / iOS 7.1 (11D167)"
      #     --get the name of window 1
      #     --get every window

      #     click button 8
      #     --get every button
      #   end tell
      # end tell
      if `which ios_webkit_debug_proxy`.strip == ''
        puts "*** Required, Install ios-webkit-debug-proxy"
        puts "brew install ios-webkit-debug-proxy"
        puts "\n\n"
        exit
      end

      if `which lsof`.strip == ''
        puts "*** Required, Install lsof-webkit-debug-proxy"
        puts "brew install lsof"
        puts "\n\n"
        exit
      end

      puts `ps x | grep "MobileSafari" | grep "iPhone Simulator" | grep -v grep`
      cmdstr = 'ps x | grep "MobileSafari.app" | grep "/iPhone Simulator/" | grep -v grep | awk \'{ print $1 }\''
      pid = `#{ cmdstr }`.to_s.strip


      unless pid=~ /[0-9]+/
        puts "\n\n"
        puts "**** PID for Mobile Safari not found", "\n\n"

        cmd = %Q{/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Applications/iPhone\\ Simulator.app/Contents/MacOS/iPhone\\ Simulator -SimulateApplication }
        cmd << %Q{/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator7.1.sdk/Applications/MobileSafari.app/MobileSafari }
        cmd << %Q{-u "http://stage-www.yellowpages.com/"}
        cmd = cmd.strip


        puts "*** Launch Simulator: #{ cmd }\n\n"

        thread_pid = fork {
          `#{cmd}`
        }
        Process.detach(thread_pid)

        sleep 10

        count = 0
        loop {
          puts cmdstr
          pid = `#{ cmdstr }`.to_s.strip
          if pid =~ /[0-9]+/
            puts "* Mobile Safari, pid: #{ pid }\n\n"
            break
          end
          if count == 10
            break
          end
          sleep 5
          count += 1
        }
        unless pid =~ /[0-9]+/
          exit
        end

        $stdout.puts "* Waiting...."
      end
      sleep 12

      pid = pid.to_i

      puts `ps x | grep "MobileSafari" | grep "iPhone Simulator" | grep -v grep`
      puts "\n\n"


      unless pid.to_s =~ /^[0-9]+$/
        puts "*** DID NOT FIND Mobile Safari pid"
        puts pid
        exit
      end

      lldb "attach -p #{pid}"
      lldb "expr -d run-target -- [WebView _enableRemoteInspector]"
      lldb "detach"
      lldb "quit"
      sleep 2

      $lldb.close
      sleep 2

      puts ""

      out = `lsof -i -P | grep -i "listen"`.strip
      if out =~ /ios_webki/
        dpid = `ps x | grep ios_webkit | grep -v grep | awk \'{ print $1 }\'`
        puts `ps x | grep ios_webkit | grep -v grep`
        puts "\n\n"

        `kill -9 #{dpid}`
        puts "* Killing pid: #{dpid}"
        sleep 5
      end

      out = `lsof -i -P | grep -i "listen"`.strip
      if !(out =~ /ios_webki/)
        puts "* Starting: ios_webkit_debug_proxy", "\n\n"

        if `which ios_webkit_debug_proxy`.strip == ''
          puts "*** Required, Install ios-webkit-debug-proxy"
          puts "brew install ios-webkit-debug-proxy"
          puts "\n\n"
          exit
        end

        debug_proxy_pid = fork {
          `ios_webkit_debug_proxy`
        }
        Process.detach(debug_proxy_pid)
      end


      inspector_found = false
      detect_inspector = lambda {
        out = `lsof -i -P | grep -i "listen"`.strip
        puts out

        if out =~ /ios_webki/
          inspector_found = true
          puts "\n\n"
          puts "****** SUCCESS! Remote Inspector is enabled "
          puts "****** Go to: http://localhost:9221/"
          puts "****** JSON Info (Pages): http://localhost:9222/json "
          puts "\n\n"
        else
          puts "\n\n"
          puts "****** FAILED! Remote Inspector is disabled "
          puts "\n\n"
        end
      }

      sleep 3

      try_count = 0
      loop {
        if inspector_found == false
          detect_inspector.call
          sleep 3
          break if try_count == 10
          break inspector_found == true
          try_count += 1
        else
          break
        end
      }

      # Look for webinspect, which means it remote inspector is working
      # Run: sudo lsof -i -P | grep -i "listen"
      #
      # webinspec 52478         fb2114    4u  IPv6 0x10c9310cc327e203      0t0    TCP localhost:27753 (LISTEN)
      #
      # Finally run:
      # `ios_webkit_debug_proxy`
      #
      # Navigate to: localhost:9221
    end
  end
end
