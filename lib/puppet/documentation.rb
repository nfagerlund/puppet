require 'puppet'
require 'puppet/util/docs'

require 'pp'

include Puppet::Util::Docs
# We use one function from this module: scrub().

# The old schema of the typedocs object:

# [
#   { :name        => 'name of type',
#     :description => 'Markdown fragment: description of type',
#     :features    => { :feature_name => 'feature description', ... }
#       # If there are no features, the :features key will be ABSENT.
#     :providers   => [ # If there are no providers, the :providers key will be ABSENT.
#       { :name        => :provider_name,
#         :description => 'Markdown fragment: docs for this provider',
#         :features    => [:feature_name, :other_feature, ...]
#           # If there are no supported features for this provider, the value
#           # of the :features key will be an EMPTY ARRAY.
#       }
#     :attributes  => [
#       { :name        => 'name of attribute',
#         :description => 'Markdown fragment: docs for this attribute',
#         :kind        => (:property || :parameter),
#         :namevar     => (true || false || nil),
#       },
#       {...etc...}
#     ],
#   },
#   { :name ..... etc.}
# ]

# The current schema of the typedocs object:

# { :name_of_type => {
#     :description => 'Markdown fragment: description of type',
#     :features    => { :feature_name => 'feature description', ... }
#       # If there are no features, the value of :features will be an empty hash.
#     :providers   => { # If there are no providers, the value of :providers will be an empty hash.
#       :name_of_provider => {
#         :description => 'Markdown fragment: docs for this provider',
#         :features    => [:feature_name, :other_feature, ...]
#           # If provider has no features, the value of :features will be an empty array.
#       },
#       ...etc...
#     }
#     :attributes  => { # Puppet dictates that there will ALWAYS be at least one attribute.
#       :name_of_attribute => {
#         :description => 'Markdown fragment: docs for this attribute',
#         :kind        => (:property || :parameter),
#         :namevar     => (true || false), # always false if :kind => :property
#       },
#       ...etc...
#     },
#   },
#   ...etc...
# }


typedocs = {}

Puppet::Type.loadall

Puppet::Type.eachtype { |type|
  # List of types to ignore:
  next if type.name == :puppet
  next if type.name == :component
  next if type.name == :whit

  # Initialize the documentation object for this type
  docobject = {}
  docobject[:description] = scrub(type.doc)
  docobject[:attributes]  = {}

  # Handle features:
  # inject will return empty hash if type.features is empty.
  docobject[:features] = type.features.inject( {} ) { |allfeatures, name|
    allfeatures[name] = scrub( type.provider_feature(name).docs )
    allfeatures
  }

  # Handle providers:
  # inject will return empty hash if type.providers is empty.
  docobject[:providers] = type.providers.inject( {} ) { |allproviders, name|
    allproviders[name] = {
      :description => scrub( type.provider(name).doc ),
      :features    => type.provider(name).features
    }
    allproviders
  }

  # Override several features missing due to bug #18426:
  if type.name == :user
    docobject[:providers][:useradd][:features] << :manages_passwords << :manages_password_age << :libuser
  end
  if type.name == :group
    docobject[:providers][:groupadd][:features] << :libuser
  end


  # Handle properties:
  docobject[:attributes].merge!(
    type.validproperties.inject( {} ) { |allproperties, name|
      property = type.propertybyname(name)
      raise "Could not retrieve property #{propertyname} on type #{type.name}" unless property
      description = property.doc
      $stderr.puts "No docs for property #{name} of #{type.name}" unless description and !description.empty?

      allproperties[name] = {
        :description => scrub(description),
        :kind        => :property,
        :namevar     => false # Properties can't be namevars.
      }
      allproperties
    }
  )

  # Handle parameters:
  docobject[:attributes].merge!(
    type.parameters.inject( {} ) { |allparameters, name|
      description = type.paramdoc(name)
      $stderr.puts "No docs for parameter #{name} of #{type.name}" unless description and !description.empty?

      allparameters[name] = {
        :description => scrub(description),
        :kind        => :parameter,
        :namevar     => type.key_attributes.include?(name) # returns a boolean
      }
      allparameters
    }
  )

  # Finally:
  typedocs[type.name] = docobject
}




# puts PP.pp(typedocs)

typedocs.keys.sort.each do |name|
  this_type = typedocs[name]

  print name.to_s + "\n-----\n\n"
  print this_type[:description] + "\n\n"

  if !this_type[:features].empty?
    print "### Features\n\n"
    featurelist = this_type[:features].keys.sort

    print featurelist.collect {|feature|
      '* `' + feature.to_s + '` --- ' + this_type[:features][feature].gsub("\n", ' ')
    }.join("\n") + "\n\n"

    if !this_type[:providers].empty?
      headers = [ "Provider", featurelist.collect{|feature| feature.to_s.gsub('_', ' ')} ].flatten
      data    = this_type[:providers].keys.inject( {} ) {|all_provider_rows, name|
        all_provider_rows[name] = featurelist.collect {|feature|
          this_type[:providers][name][:features].include?(feature) ? "*X*" : ''
        }
        all_provider_rows
      }

      print doctable(headers, data)
    end
  end

  if !this_type[:providers].empty?
    print "### Providers\n\n"
    print this_type[:providers].keys.sort.collect {|name|
      "#### " + name.to_s + "\n\n" + this_type[:providers][name][:description]
    }.join("\n\n") + "\n\n"
  end

  print "### Attributes\n\n"
  print this_type[:attributes].keys.sort {|a,b|
    # Float namevar to top and ensure to second-top
    if this_type[:attributes][a][:namevar]
      -1
    elsif this_type[:attributes][b][:namevar]
      1
    elsif a == :ensure
      -1
    elsif b == :ensure
      1
    else
      a <=> b
    end
  }.collect {|name|
    "#### " + name.to_s + "\n\n" +
    '(' + this_type[:attributes][name][:kind].to_s + ")\n\n" +
    (this_type[:attributes][name][:namevar] ? "**(namevar)**\n\n" : '') +
    this_type[:attributes][name][:description] +
    (name == :provider ? "\n\n" + "Available providers are:\n\n" + this_type[:providers].keys.collect {|prov| "* `#{prov.to_s}`"}.sort.join("\n") : '')
  }.join("\n\n") + "\n\n"
end