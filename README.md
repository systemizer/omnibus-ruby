## Get Started

To get started using Omnibus, create a new project and add it to your Gemfile.

```ruby
gem 'omnibus', :git => 'git@github.com/opscode/omnibus-ruby'
```

In your Rakefile, generate the require the Omnibus gem and load your project and software congifurations to generate the tasks.

```ruby
require 'omnibus'

Omnibus.projects('config/projects/*.rb')
Omnibus.software('config/software/*/.rb')
```

If you've already set up software and project configurations, executing `rake -T` prints a list of things that you can build:

```
rake projects:chef                    # build and package chef
rake prokects:chef:software:ruby      # fetch and build ruby
rake projects:chef:software:rubygems  # fetch and build rubygems
rake prokects:chef:software:chef-gem  # fetch and build chef-gem
```

Executing `rake projects:chef` will recursively build all of the dependencies of Chef from scratch. In the case above, Ruby is build first, followed by the installation of Rubygems. Finally, Chef is installed from gems. Executing the top-level project task (projects:chef) also packages the project for distribution on the target platform (e.g. RPM on RedHat-based systems and DEB on Debian-based systems).

## Configuration DSL

### Software

```ruby
name    "ruby"
version "1.9.2-p290"
source  :url => "http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-#{version}.tar.gz",
        :md5 => "604da71839a6ae02b5b5b5e1b792d5eb"

dependencies ["zlib", "ncurses", "openssl"]

relative_path "ruby-#{version}"

build do
  command "./configure"
  command "make"
  command "make install"
end
```

**name**: The name of the software component.

**version**: The version of the software component.

**source**: Directions to the location of the source.

**dependencies**: A list of components that this software depends on.

**relative_path**: The relative path of the extracted tarball.

**build**: The build instructions.

**command**: An individual build step.

### Project DSL