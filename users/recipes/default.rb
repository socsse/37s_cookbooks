require_recipe 'ruby-shadow'

groups = search(:groups)

# first, create all active groups
#
groups.each do |group|
  if node[:active_groups].include?(group[:id])
    group group[:id] do
      group_name group[:id]
      gid group[:gid]
      action [ :create, :modify, :manage ]
    end
  end
end


# create all users beloging to active groups
#
groups.each do |group|

  if node[:active_groups].include?(group[:id])

    search(:users, "groups:#{group[:id]}").each do |user|

      home_dir = user[:home_dir] || "/home/#{user[:id]}"
      user user[:id] do
        comment user[:full_name]
        uid user[:uid]

        primary_group = nil
        user[:groups].each do |g|
          group_name = g.to_s
          if node[:active_groups].include?(group_name)
            primary_group = g
            break
          end
        end
        if !primary_group.nil?
          gid primary_group
        end

        home home_dir
        shell user[:shell] || "/bin/bash"
        password user[:password]
        supports :manage_home => false
        action [:create, :manage]
      end
      
      user[:groups].each do |g|
        group g do
          group_name g.to_s
          # only add user to group if it is an active group
          if node[:active_groups].include?(group_name)
            gid groups.find { |grp| grp[:id] == g }[:gid]
            members [user[:id]]
            append true
            action [ :create, :modify, :manage ]
          end
        end
      end

      if (node[:users][:manage_files] || user[:local_files] == true)
        directory "#{home_dir}" do
          owner user[:id]
          group user[:groups].first.to_s
          mode 0700
          recursive true
        end

        directory "#{home_dir}/.ssh" do
          action :create
          owner user[:id]
          group user[:groups].first.to_s
          mode 0700
        end

        keys = Mash.new
        keys[user[:id]] = user[:ssh_key]

        if user[:ssh_key_groups]
          user[:ssh_key_groups].each do |group|
            users = search(:users, "groups:#{group}")
            users.each do |key_user|
              keys[key_user[:id]] = key_user[:ssh_key]
            end
          end
        end
      
        if user[:extra_ssh_keys]
          user[:extra_ssh_keys].each do |username|
            keys[username] = search(:users, "id:#{username}").first[:ssh_key]
          end
        end

        template "#{home_dir}/.ssh/authorized_keys" do
          source "authorized_keys.erb"
          action :create
          owner user[:id]
          group user[:groups].first.to_s
          variables(:keys => keys)
          mode 0600
          not_if { user[:preserve_keys] }
        end
      else
        log "Not managing files for #{user[:id]} because home directory does not exist or this is not a management host." do
          level :debug
        end
      end
    end
  end
end

# Remove initial setup user and group.
#
# Not really sure how this it to work because if we are user ubuntu (which is the case before we add new users)
# then we are not allowed to remove ourselves.
#
#user  "ubuntu" do
#  action :remove
#end

#group "ubuntu" do
#  action :remove
#end
