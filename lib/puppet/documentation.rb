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
      provider_object = {
        :name        => provider,
        :description => scrub( type.provider(provider).doc ),
        :features    => type.provider(provider).features
      }
      # Overrides for missing features due to bug #18426:
      if type.name == :user and provider_object[:name] == :useradd
        provider_object[:features] << :manages_passwords << :manages_password_age << :libuser
      end
      if type.name == :group and provider_object[:name] == :groupadd
        provider_object[:features] << :libuser
      end

      docobject[:providers] << provider_object
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

typedocs.sort {|a,b| a[:name] <=> b[:name] }.each do |this_type|
  print this_type[:name].to_s + "\n-----\n\n"
  print this_type[:description] + "\n\n"

  if this_type[:features]
    print "### Features\n\n"
    featurelist = this_type[:features].keys.sort
    print featurelist.collect {|feature|
      '* `' + feature.to_s + '` --- ' + this_type[:features][feature].gsub("\n", ' ')
    }.join("\n") + "\n\n"

    if this_type[:providers]
      headers = ["Provider", featurelist.collect{|feature| feature.to_s.gsub('_', ' ')}].flatten
      data = {}
      this_type[:providers].each do |provider|
        data[provider[:name]] = []
        featurelist.each do |feature|
          if provider[:features].include?(feature)
            data[provider[:name]] << "*X*"
          else
            data[provider[:name]] << ""
          end
        end
      end

      print doctable(headers, data)
    end
  end

  # print "### Old-style Featuredocs\n\n" + this_type[:featuredocs] + "\n\n" if this_type[:featuredocs]

  if this_type[:providers]
    print "### Providers\n\n"
    this_type[:providers].sort {|a,b|
      a[:name] <=> b[:name]
    }.each do |provider|
      print "#### " + provider[:name].to_s + "\n\n"
      print provider[:description] + "\n\n"
      print "Supported features: " + provider[:features].collect {|prov| '`' + prov.to_s + '`'}.sort.join(', ') + "\n\n"
    end
  end

  print "### Attributes\n\n"
  this_type[:attributes].sort {|a,b|
    a[:name] <=> b[:name]
  }.each do |attribute|
    print "#### " + attribute[:name].to_s + "\n\n"
    print '(' + attribute[:kind].to_s + ")\n\n"
    print "**namevar**\n\n" if attribute[:namevar]
    print attribute[:description] + "\n\n"
  end
end