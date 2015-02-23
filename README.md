# Flores - a stress testing library

When writing tests, it is often good to test a wide variety of inputs to ensure
your entire input range behaves correctly.

Further, adding a bit of randomness in your tests can help find bugs.

## Why Flores?

Randomization helps you cover a wider range of inputs to your tests to find bugs. Stress
testing (run a test repeatedly) helps you find bugs faster. We can use stress testing results
to find common patterns in failures!

Let's look at a sample situation. Ruby's TCPServer. Let's write a spec to cover a spec covering port binding:

```ruby
describe TCPServer do
  subject(:socket) { Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0) }
  let(:port) { 5000 }
  let(:sockaddr) { Socket.sockaddr_in(port, "127.0.0.1") }

  after { socket.close}

  it "should bind successfully" do
    socket.bind(sockaddr)
    expect(socket.local_address.ip_port).to(be == port)
  end
end
```

Running it:

```
% rspec tcpserver_spec.rb
.

Finished in 0.00248 seconds (files took 0.16294 seconds to load)
1 example, 0 failures
```

That's cool. We now have some confidence that TCPServer on port 5000 will bind successfully.

What about the other ports? What ranges of values should work? What shouldn't?

Let's assume I don't know anything about tcp port ranges and test randomly in the range -100,000 to +100,000:

```ruby
describe TCPServer do
  let(:port) { Randomized.integer(-100_000..100_000) }
  ...
end
```

Running it:

```
% rspec tcpserver_spec.rb
F

Failures:

  1) TCPServer should bind successfully
     Failure/Error: expect(socket.local_address.ip_port).to(be == port)
       expected: == 83359
            got:    17823
     # ./tcpserver_spec.rb:12:in `block (2 levels) in <top (required)>'

Finished in 0.00155 seconds (files took 0.10221 seconds to load)
1 example, 1 failure
```

Well that's weird. Binding port 83359 actually made it bind on port 17823!

If we run it more times, we'll see all kinds of different results:

* Run 1:
  ```
     Failure/Error: expect(socket.local_address.ip_port).to(be == port)
       expected: == 83359
            got:    17823
  ```
* Run 2:
  ```
     Failure/Error: let(:sockaddr) { Socket.sockaddr_in(port, "127.0.0.1") }
     SocketError:
       getaddrinfo: nodename nor servname provided, or not known
  ```
* Run 3:
  ```
     Errno::EACCES:
       Permission denied - bind(2) for 127.0.0.1:615
  ```
* Run 4:
  ```
     Finished in 0.00161 seconds (files took 0.10356 seconds to load)
     1 example, 0 failures
  ```

## Analyze the results

The above example showed that there were many different kinds of failures when
we introduced randomness to our test inputs.

We can go further and run a given spec example many times and group the
failures by similarity and include context (what the inputs were, etc)

This library provides an `analyze_it` helper which behaves similarly to rspec's
`it` except that it runs the block a random number of times and clears the `let` cache
each time. This lets you run  a given test many times with many random inputs!

The result is grouped by failure and includes context. Let's see how it works:

We'll change `it` to use `analyze_it` instead:

```diff
- it "should bind successfully" do
+ analyze_it "should bind successfully", [:port] do
```

Now rerunning the test. With barely any spec changes from the original, we have
now enough randomness and stress testing to identify many different failure cases
and input ranges for those failures.

```
Failures:

  1) TCPServer should bind successfully
     Failure/Error: raise StandardError, Analysis.new(results) if results.any? { |k, _| k != :success }
     StandardError:
       31.14% tests successful of 2563 tests
       Failure analysis:
         50.57% -> [1296] SocketError
           Sample exception for {:port=>-94900}
             getaddrinfo: nodename nor servname provided, or not known
           Samples causing SocketError:
             {:port=>-49441}
             {:port=>-1991}
             {:port=>-54074}
             {:port=>-1733}
             {:port=>-21868}
         16.89% -> [433] RSpec::Expectations::ExpectationNotMetError
           Sample exception for {:port=>93844}
             expected: == 93844
                  got:    28308
           Samples causing RSpec::Expectations::ExpectationNotMetError:
             {:port=>89451}
             {:port=>95627}
             {:port=>95225}
             {:port=>73106}
             {:port=>77167}
         1.01% -> [26] Errno::EACCES
           Sample exception for {:port=>65649}
             Permission denied - bind(2) for 127.0.0.1:113
           Samples causing Errno::EACCES:
             {:port=>913}
             {:port=>141}
             {:port=>66194}
             {:port=>66217}
             {:port=>66408}
         0.39% -> [10] Errno::EADDRINUSE
           Sample exception for {:port=>34402}
             Address already in use - bind(2) for 127.0.0.1:34402
           Samples causing Errno::EADDRINUSE:
             {:port=>50905}
             {:port=>71202}
             {:port=>34402}
             {:port=>28235}
             {:port=>85641}
     # ./lib/rspec/stress_it.rb:103:in `block in analyze_it'

Finished in 0.0735 seconds (files took 0.10247 seconds to load)
1 example, 1 failure

Failed examples:

rspec ./tcpserver_spec.rb:8 # TCPServer should bind successfully
```
