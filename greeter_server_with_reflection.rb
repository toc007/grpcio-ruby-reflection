#!/usr/bin/ruby

# Copyright 2015 gRPC authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Sample gRPC server that implements the Greeter::Helloworld service.
#
# Usage: $ path/to/greeter_server.rb

this_dir = File.expand_path(File.dirname(__FILE__))
lib_dir = File.join(this_dir, 'lib')
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)

require 'grpc'
require 'reflection_services_pb'
require 'reflection_pb'

# ReflectionServer implements the ServerReflection template
class ReflectionServer < Grpc::Reflection::V1alpha::ServerReflection::Service
  def server_reflection_info(reflect_req)
    p "server_reflection_info called"
    ReflectionEnumerator.new(reflect_req).each_item
  end
end

class ReflectionEnumerator
  @requests
  def initialize(reflect_reqs)
    @requests = reflect_reqs
  end

  def each_item
    return enum_for(:each_item) unless block_given?
    begin
      # send back the earlier messages at this point
      @requests.each do |r|
        # Create a ServiceResponse
        #   User specified or auto generated?
        puts Grpc::Reflection::V1alpha::ServerReflection::Service.methods
        service_names = ["hello", "world"]
        services = service_names.map do |s| 
          Grpc::Reflection::V1alpha::ServiceResponse.new(:name => s)
        end

        serviceResponse = Grpc::Reflection::V1alpha::ListServiceResponse.new(
          :service => services
        )
        puts serviceResponse.class

        response = Grpc::Reflection::V1alpha::ServerReflectionResponse.new(
          :valid_host => "ruby_reflection_server",
          :original_request => r,
          :list_services_response => serviceResponse
        )
        puts response.to_s
        yield response
      end
    rescue StandardError => e
      fail e # signal completion via an error
    end
  end
end

# main starts an RpcServer that receives requests to GreeterServer at the sample
# server port.
def main
  s = GRPC::RpcServer.new
  s.add_http2_port('0.0.0.0:50051', :this_port_is_insecure)
  s.handle(ReflectionServer)
  s.run_till_terminated
end

main
