require 'puppet'
require 'puppet/util/docs'

require 'pp'

include Puppet::Util::Docs
# We use one function from this module: scrub().

# The schema of the typedocs object:

# [
#   { :name        => 'name of type',
#     :description => 'description of type',
#     :featuredocs => '??? (lib/puppet/util/provider_features.rb, in #featuredocs)',
#     :features    => { :feature_name => 'feature description', ... }
#     :providers   => [
#       { :name        => :provider_name,
#         :description => 'docs for this provider',
#         :features    => [:feature_name, :other_feature, ...]
#       }
#     :attributes  => [
#       { :name        => 'name of attribute',
#         :description => 'docs for this attribute',
#         :kind        => (:property || :parameter),
#         :namevar     => (true || nil),
#       },
#       {...etc...}
#     ],
#   },
#   { :name ..... etc.}
# ]


types = {}
Puppet::Type.loadall

Puppet::Type.eachtype { |type|
  next if type.name == :puppet
  next if type.name == :component
  next if type.name == :whit
  types[type.name] = type
#   puts "#{type.name}'s key attributes:"
#   puts type.key_attributes.inspect
}

typedocs = []

types.each { |name,type|
  docobject = {}
  docobject[:name] = name
  docobject[:description] = scrub(type.doc)
  docobject[:attributes] = []

  if featuredocs = type.featuredocs
    docobject[:featuredocs] = featuredocs
  end

  unless type.features.empty?
    docobject[:features] = type.features.inject( {} ) { |allfeatures, name|
      allfeatures[name] = scrub( type.provider_feature(name).docs )
      allfeatures
    }
  end

  if type.providers.length > 0
    docobject[:providers] ||= []
    type.providers.each do |provider|
      docobject[:providers] << {
        :name        => provider,
        :description => scrub( type.provider(provider).doc ),
        :features    => type.provider(provider).features
      }
    end
  end

  type.validproperties.each { |propertyname|
    property = type.propertybyname(propertyname)
    raise "Could not retrieve property #{sname} on type #{type.name}" unless property
    unless description = property.doc
      $stderr.puts "No docs for #{type}[#{sname}]"
      next
    end
    docobject[:attributes] << {:name => propertyname, :description => scrub(description), :kind => :property}
  }

  type.parameters.each { |paramname|
    namevar = true if type.key_attributes.include?(paramname)
    docobject[:attributes] << {:name => paramname, :description => scrub(type.paramdoc(paramname)), :kind => :parameter, :namevar => (namevar || nil)}
  }

  typedocs << docobject

}


# puts PP.pp(typedocs)

typedocs.each do |this_type|
  print this_type[:name].to_s + "\n-----\n\n"
  print this_type[:description] + "\n\n"
  print "### Features\n\n" + this_type[:features].inspect + "\n\n" if this_type[:features]
  print "### Old-style Featuredocs\n\n" + this_type[:featuredocs] + "\n\n" if this_type[:featuredocs]
  print "### Providers\n\n" + this_type[:providers].inspect + "\n\n" if this_type[:providers]
  print "### Attributes\n\n"
  this_type[:attributes].each do |attribute|
    print "#### " + attribute[:name].to_s + "\n\n"
    print '(' + attribute[:kind].to_s + ")\n\n"
    print "**namevar**\n\n" if attribute[:namevar]
    print attribute[:description] + "\n\n"
  end
end