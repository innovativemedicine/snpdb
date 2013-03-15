module Puppet::Parser::Functions
    newfunction(:set_hive_properties, :type => :rvalue) do |args|
        return args.each_slice(2).collect { |name, value| 
            [
                "set /files/etc/hive/conf/hive-site.xml/configuration/property[*][name/#text='#{name}']/name/#text #{name}",
                "set /files/etc/hive/conf/hive-site.xml/configuration/property[*][name/#text='#{name}']/value/#text #{value}",
            ]
        }.flatten
    end
end
