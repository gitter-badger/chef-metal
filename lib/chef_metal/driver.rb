module ChefMetal
  #
  # A Driver instance represents a place where machines can be created and found,
  # and contains methods to create, delete, start, stop, and find them.
  #
  # For AWS, a Driver instance corresponds to a single account.
  # For Vagrant, it is a directory where VM files are found.
  #
  # = How to Make a Driver
  #
  # To implement a Driver, you must implement the following methods:
  #
  # * initialize(driver_url) - create a new driver with the given URL
  # * driver_url - a URL representing everything unique about your driver. (NOT credentials)
  # * allocate_machine - ask the driver to allocate a machine to you.
  # * ready_machine - get the machine "ready" - wait for it to be booted and accessible (for example, accessible via SSH transport).
  # * stop_machine - stop the machine.
  # * destroy_machine - delete the machine.
  # * connect_to_machine - connect to the given machine.
  #
  # Optionally, you can also implement:
  # * allocate_machines - allocate an entire group of machines.
  # * ready_machines - get a group of machines warm and booted.
  # * stop_machines - stop a group of machines.
  # * destroy_machines - delete a group of machines.
  #
  # Additionally, you must create a file named `chef_metal/driver_init/<scheme>.rb`,
  # where <scheme> is the name of the scheme you chose for your driver_url. This
  # file, when required, must call ChefMetal.add_registered_driver(<scheme>, <class>).
  # The given <class>.from_url(url, config) will be called with a driver_url and
  # configuration.
  #
  # All of these methods must be idempotent - if the work is already done, they
  # just don't do anything.
  #
  class Driver
    #
    # Inflate a driver from a driver URL.
    #
    #
    # @param [String] driver_url  the URL to inflate the driver
    # config - a configuration hash.  See "config" for a list of known keys.
    #
    # == Returns
    # A Driver representing the given driver_url.
    #
    def initialize(driver_url, config)
      @driver_url = driver_url
      @config = config
    end

    #
    # Override this on specific driver classes
    #
    def self.from_url(driver_url, config)
      ChefMetal.from_url(driver_url, config)
    end

    #
    # A URL representing the driver and the place where machines come from.
    # This will be stuffed in machine_spec.location['driver_url'] so that the
    # machine can be re-inflated.  URLs must have a unique scheme identifying the
    # driver class, and enough information to identify the place where created
    # machines can be found.  For AWS, this is the account number; for lxc and
    # vagrant, it is the directory in which VMs and containers are.
    #
    # For example:
    # - fog:AWS:123456789012
    # - vagrant:/var/vms
    # - lxc:
    # - docker:
    #
    attr_reader :driver_url

    # A configuration hash.  These keys may be present:
    #   - :driver_options: a driver-defined object containing driver config.
    #   - :private_keys: a hash of private keys, with a "name" and a "value".  Values are either strings (paths) or PrivateKey objects.
    #   - :private_key_paths: a list of paths to directories containing private keys.
    #   - :write_private_key_path: the path to which we write new keys by default.
    #   - :log_level: :debug/:info/:warn/:error/:fatal
    #   - :chef_server_url: url to chef server
    #   - :node_name: username to talk to chef server
    #   - :client_key: path to key used to talk to chef server
    attr_reader :config

    #
    # Driver configuration. Equivalent to config[:driver_options] || {}
    #
    def driver_options
      config[:driver_options] || {}
    end


    # Allocate a machine from the underlying service.  This method
    # does not need to wait for the machine to boot or have an IP, but it must
    # store enough information in machine_spec.location to find the machine
    # later in ready_machine.
    #
    # If a machine is powered off or otherwise unusable, this method may start
    # it, but does not need to wait until it is started.  The idea is to get the
    # gears moving, but the job doesn't need to be done :)
    #
    # @param [ChefMetal::ActionHandler] action_handler The action_handler object that is calling this method
    # @param [ChefMetal::MachineSpec] machine_spec A machine specification representing this machine.
    # @param [Hash] machine_options A set of options representing the desired options when
    # constructing the machine
    #
    # @return [ChefMetal::MachineSpec] Modifies the passed-in machine_spec.  Anything in here will be saved
    # back after allocate_machine completes.
    #
    def allocate_machine(action_handler, machine_spec, machine_options)
      raise "#{self.class} does not implement allocate_machine"
    end

    # Ready a machine, to the point where it is running and accessible via a
    # transport. This will NOT allocate a machine, but may kick it if it is down.
    # This method waits for the machine to be usable, returning a Machine object
    # pointing at the machine, allowing useful actions like setup, converge,
    # execute, file and directory.
    #
    #
    # @param [ChefMetal::ActionHandler] action_handler The action_handler object that is calling this method
    # @param [ChefMetal::MachineSpec] machine_spec A machine specification representing this machine.
    # @param [Hash] machine_options A set of options representing the desired state of the machine
    #
    # @return [Machine] A machine object pointing at the machine, allowing useful actions like setup,
    # converge, execute, file and directory.
    #
    def ready_machine(action_handler, machine_spec, machine_options)
      raise "#{self.class} does not implement ready_machine"
    end

    # Connect to a machine without allocating or readying it.  This method will
    # NOT make any changes to anything, or attempt to wait.
    #
    # @param [ChefMetal::MachineSpec] machine_spec MachineSpec representing this machine.
    # @param [Hash] machine_options
    # @return [Machine] A machine object pointing at the machine, allowing useful actions like setup,
    # converge, execute, file and directory.
    #
    def connect_to_machine(machine_spec, machine_options)
      raise "#{self.class} does not implement connect_to_machine"
    end


    # Delete the given machine --  destroy the machine,
    # returning things to the state before allocate_machine was called.
    #
    # @param [ChefMetal::ActionHandler] action_handler The action_handler object that is calling this method
    # @param [ChefMetal::MachineSpec] machine_spec A machine specification representing this machine.
    # @param [Hash] machine_options A set of options representing the desired state of the machine
    def destroy_machine(action_handler, machine_spec, machine_options)
      raise "#{self.class} does not implement destroy_machine"
    end

    # Stop the given machine.
    #
    # @param [ChefMetal::ActionHandler] action_handler The action_handler object that is calling this method
    # @param [ChefMetal::MachineSpec] machine_spec A machine specification representing this machine.
    # @param [Hash] machine_options A set of options representing the desired state of the machine
    def stop_machine(action_handler, machine_spec, machine_options)
      raise "#{self.class} does not implement stop_machine"
    end

    # Allocate an image. Returns quickly with an ID that tracks the image.
    #
    # @param [ChefMetal::ActionHandler] action_handler The action_handler object that is calling this method
    # @param [ChefMetal::ImageSpec] image_spec A machine specification representing this machine.
    # @param [Hash] image_options A set of options representing the desired state of the machine
    def allocate_image(action_handler, image_spec, image_options, machine_spec)
      raise "#{self.class} does not implement create_image"
    end

    # Ready an image, waiting till the point where it is ready to be used.
    #
    # @param [ChefMetal::ActionHandler] action_handler The action_handler object that is calling this method
    # @param [ChefMetal::ImageSpec] image_spec A machine specification representing this machine.
    # @param [Hash] image_options A set of options representing the desired state of the machine
    def ready_image(action_handler, image_spec, image_options)
      raise "#{self.class} does not implement ready_image"
    end

    # Destroy an image using this service.
    #
    # @param [ChefMetal::ActionHandler] action_handler The action_handler object that is calling this method
    # @param [ChefMetal::ImageSpec] image_spec A machine specification representing this machine.
    # @param [Hash] image_options A set of options representing the desired state of the machine
    def destroy_image(action_handler, image_spec, image_options)
      raise "#{self.class} does not implement destroy_image"
    end

    #
    # Optional interface methods
    #

    #
    # Allocate a set of machines.  This should have the same effect as running
    # allocate_machine on all machine_specs.
    #
    # Drivers do not need to implement this; the default implementation
    # calls acquire_machine in parallel.
    #
    # == Parallelizing
    #
    # The parallelizer must implement #parallelize
    # @example Example parallelizer
    #   parallelizer.parallelize(specs_and_options) do |machine_spec|
    #     allocate_machine(action_handler, machine_spec)
    #   end.to_a
    #   # The to_a at the end causes you to wait until the parallelization is done
    #
    # This object is shared among other chef-metal actions, ensuring that you do
    # not go over parallelization limits set by the user.  Use of the parallelizer
    # to parallelizer machines is not required.
    #
    # == Passing a block
    #
    # If you pass a block to this function, each machine will be yielded to you
    # as it completes, and then the function will return when all machines are
    # yielded.
    #
    # @example Passing a block
    #   allocate_machines(action_handler, specs_and_options, parallelizer) do |machine_spec|
    #     ...
    #   end
    #
    # @param [ChefMetal::ActionHandler] action_handler The action_handler object that is calling this method; this
    #        is generally a driver, but could be anything that can support the
    #        interface (i.e., in the case of the test kitchen metal driver for
    #        acquiring and destroying VMs).
    # @param [Hash] specs_and_options A hash of machine_spec -> machine_options representing the
    #                 machines to allocate.
    # @param [Parallelizer] parallelizer an object with a parallelize() method that works like this:
    # @return [Array<Machine>] An array of machine objects created
    def allocate_machines(action_handler, specs_and_options, parallelizer)
      parallelizer.parallelize(specs_and_options) do |machine_spec, machine_options|
        allocate_machine(add_prefix(machine_spec, action_handler), machine_spec, machine_options)
        yield machine_spec if block_given?
        machine_spec
      end.to_a
    end

    # Ready machines in batch, in parallel if possible.
    def ready_machines(action_handler, specs_and_options, parallelizer)
      parallelizer.parallelize(specs_and_options) do |machine_spec, machine_options|
        machine = ready_machine(add_prefix(machine_spec, action_handler), machine_spec, machine_options)
        yield machine if block_given?
        machine
      end.to_a
    end

    # Stop machines in batch, in parallel if possible.
    def stop_machines(action_handler, specs_and_options, parallelizer)
      parallelizer.parallelize(specs_and_options) do |machine_spec, machine_options|
        stop_machine(add_prefix(machine_spec, action_handler), machine_spec, machine_options)
        yield machine_spec if block_given?
      end.to_a
    end

    # Delete machines in batch, in parallel if possible.
    def destroy_machines(action_handler, specs_and_options, parallelizer)
      parallelizer.parallelize(specs_and_options) do |machine_spec, machine_options|
        destroy_machine(add_prefix(machine_spec, action_handler), machine_spec, machine_options)
        yield machine_spec if block_given?
      end.to_a
    end

    # Allocate a load balancer
    # @param [ChefMetal::ActionHandler] action_handler The action handler
    # @param [ChefMetal::LoadBalancerSpec] lb_spec Frozen LB specification
    # @param [Hash] lb_options A hash of options to pass the LB
    def allocate_load_balancer(action_handler, lb_spec, lb_options)
    end

    # Make the load balancer ready
    # @param [ChefMetal::ActionHandler] action_handler The action handler
    # @param [ChefMetal::LoadBalancerSpec] lb_spec Frozen LB specification
    # @param [Hash] lb_options A hash of options to pass the LB
    def ready_load_balancer(action_handler, lb_spec, lb_options)
    end

    # Destroy the load balancer
    # @param [ChefMetal::ActionHandler] action_handler The action handler
    # @param [ChefMetal::LoadBalancerSpec] lb_spec Frozen LB specification
    # @param [Hash] lb_options A hash of options to pass the LB
    def destroy_load_balancer(action_handler, lb_spec, lb_options)
    end

    def update_load_balancer(action_handler, lb_spec, lb_options, opts = {})
    end

    protected

    def add_prefix(machine_spec, action_handler)
      AddPrefixActionHandler.new(action_handler, "[#{machine_spec.name}] ")
    end

    def get_private_key(name)
      Cheffish.get_private_key(name, config)
    end
  end
end
