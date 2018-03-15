
  set :application,     "pop"
  set :repo_url,        "git@github.com:dschmura/pop.git"
  set :user,            'deployer'
  set :puma_threads,    [4, 16]
  set :puma_workers,    0

  # Don't change these unless you know what you're doin
  set :pty,             true
  set :use_sudo,        false
  set :stage,           :production
  set :deploy_via,      :remote_cache
  set :deploy_to,       "/home/#{fetch(:user)}/apps/pop"
  set :puma_bind,       "unix://#{shared_path}/tmp/sockets/pop-puma.sock"
  set :puma_state,      "#{shared_path}/tmp/pids/puma.state"
  set :puma_pid,        "#{shared_path}/tmp/pids/puma.pid"
  set :puma_access_log, "#{release_path}/log/puma.error.log"
  set :puma_error_log,  "#{release_path}/log/puma.access.log"
  set :ssh_options,     { forward_agent: true, user: fetch(:user), keys: %w(~/.ssh/id_rsa.pub) }
  set :puma_preload_app, false
  set :puma_worker_timeout, nil
  set :puma_init_active_record, true  # Change to false when not using ActiveRecord
  set :nginx_sites_enabled_path, "/etc/nginx/sites-enabled"

  namespace :puma do
    desc 'Create Directories for Puma Pids and Socket'
    task :make_dirs do
      on roles(:app) do
        execute "mkdir #{shared_path}/tmp/sockets -p"
        execute "mkdir #{shared_path}/tmp/pids -p"
      end
    end

      before :start, :make_dirs
  end

  namespace :deploy do

    desc "Make sure local git is in sync with remote."
    task :check_revision do
      on roles(:app) do
        unless `git rev-parse HEAD` == `git rev-parse origin/master`
          puts "WARNING: HEAD is not the same as origin/master"
          puts "Run `git push` to sync changes."
        exit
      end
    end
  end

    desc 'Initial Deploy'
      task :initial do
      on roles(:app) do
        before 'deploy:restart', 'puma:start'
        invoke 'deploy'
      end
    end

    desc 'Run rake yarn:install'
    task :yarn_install do
      on roles(:web) do
        within release_path do
          execute("cd #{release_path} && yarn install")
        end
      end
    end

    # desc 'Configure nginx on server'
    # task :nginx_install do
    #   on roles (:app) do
    #     within '/etc/nginx/sites-enabled/' do
    #       execute("ln -nfs /home/deployer/apps/pop/current/config/nginx.conf /etc/nginx/sites-enabled/pop && rm /etc/nginx/sites-enabled/default")
    #     end
    #   end
    # end

    desc 'Restart application'
      task :restart do
        on roles(:app), in: :sequence, wait: 5 do
        invoke 'puma:restart'
      end
    end

    desc 'Upload to shared/config'
      task :upload do
      on roles (:app) do
        upload! "config/master.key",  "#{shared_path}/config/master.key"
        upload! "config/puma.sample.rb",  "#{shared_path}/config/puma.rb"
        upload! "config/nginx.sample.conf",  "#{shared_path}/config/nginx.conf"
      end
    end

  before :starting,  :check_revision
  # before "deploy:assets:precompile", "deploy:yarn_install"
  # after  :finishing, :compile_assets
  after  :finishing, :cleanup

  end

  desc "Run rake db:seed on a remote server."
  task :seed do
    on roles (:app) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, "db:seed"
        end
      end
    end
  end

  # ps aux | grep puma    # Get puma pid
  # kill -s SIGUSR2 pid   # Restart puma
  # kill -s SIGTERM pid   # Stop puma
  ## Linked Files & Directories (Default None):

  set :linked_files, %w{config/puma.rb config/master.key config/nginx.conf}
  set :linked_dirs,  %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}
  set :linked_dirs, fetch(:linked_dirs, []).push('public/packs', 'node_modules')
