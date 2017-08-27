sub help {
   print <<EOM;


  ${colorBold}H E L P  for $prgname $ver${colorNoBold}

  ${colorGreen}Command line tool for portal${colorNormal}
  
   ${colorRed}show${colorNormal}
    --help                this help site
    --showall             show all server
    --showsrv <name>      show all infos for server
    --gettyp <server>     get typ of server
    --getmac <server>     get mac of server
    --getctrl <server>    get control (vc, pool, model) of server
    
   ${colorRed}portal jobs${colorNormal}
    --deldb               delete db
    --delid <srvid>       delete server config in db
    --delsrv <name>       delete server config with name in db
    --new                 create new db and drop old
    --update              update db with new server or delete old one
    --sortid              sort server id 
    --backup <basedir>    backup fsi portal config to base dir - create fcb_<date><time> backup dir fcb=fsi cfg backup
    --restore <dir>       restore fsi config from files in dir
    --chkcfg              check fsi portal and server config and add defaults if missing

   ${colorRed}flag jobs${colorNormal}
    --delflag <name>      delete flag (name) content, if no --server or --pool defined, delete on all server
    --pool <name>         pool specify (or with delflag use it for vc)
    --setflag <name>      set flag, need --set, if --server all or no --server defined, set on all server, also --pool
    --server <name>       set server or "all" for all
    --set <content>       set content to set in flag

   ${colorRed}portal jobs${colorNormal}
    --haon <pool>         enable ha, if configure
    --haoff <pool>        disable ha, if configure and on

   ${colorRed}server jobs${colorNormal}
    --install <srv>       install server
    --abort <srv>         abort server installation
    --srvon <srv>         power on server
    --srvoff <srv>        power off server
    --boothd <srv>        set hp server boot force to hd
    --bootnic <srv>       set hp server boot force to nic
    --setsym <srv>        set symlink for server installation
    --delsym <srv>        delete symlink for server installation
    --upd <name>          update server if xen, esxi or centos
      --autoreboot        reboot server if update needed automatically after update procedure ended

   ${colorRed}xen pool jobs${colorNormal}
    --pooloff <pool>      power off pool server
    --dpcd <pool>         delete pool config dir of given pool name
    --dprd <pool>         delete pool running dir of given pool name
    
   ${colorRed}check jobs${colorNormal}
    --chkall              check log, master, sym, counter, end inst, online
    --daemon              run check all task for ever or stop signal
    --chklog              check if log file exist in install dir
    --chkmaster <pool>    check and set master flag if xen server, if pool not given or all = check all pools
    --sym                 check symlinks for installation start
    --xpc                 set xen pool counter
    --chkon               check online of all server and set flags
    --chkonsrv <server>   check if named server is online and set flag
    --chkiend <server>    check server name if installation finish
    --chkiae              check all server if installation finish
    --chkpoolrun          check where xen pool.run exist
    --chkha <pool>        check if in pool (name or all) ha is enabled
    --chkpatch <name>     check patch status of all or named server
    --chkpatchp <pool>    check patch status of all server in pool 

   ${colorRed}vm tasks${colorNormal}
    --vmxen <job,poolmaster,vm uuid>[<,host,vm name,user>]
            <job>         VM job = stop,start,shutdown,reboot,reset
            <poolmaster>  Xen poolmaster
            <vm uuid>     UUID of vm to do job
            <host>        optional host
            <vm name>     optional vm name
            <user>        optional user for add to tasklist as owner
            
   ${colorRed}portal status${colorNormal}
    --taskstat            return status overview
    --tasklist            show portal task list
    --taskadd <parm>      add new task to tasklist - parameter with NO space
                          parm: <short>,<long>,<jobuser>,<url>,<logdatei>,<control>,<ctyp>,<block>
    --taskdel <id>        del task from tasklist with ID
    --nounblock           if del task, do not unblock
    --taskok <control>    test if new task can add for control (servername, poolname, vc name)
    --taskfind <control>  find task id for server or pool or vc
    --block               if find task, only task which blocked
   
    --workerlist          show all portal workers
    --workerdel <typ,who> del worker entry in DB with typ and who
    --workeradd <parm>    add new worker entry to worker db
                          parm: <typ,who,status,info>
    
   ${colorRed}Log${colorNormal}
    -dbport               change postgresql port (or use a db pooler)
    -l <logname>          set log filename (without .log)
    -q                    screen quiet mode - no screen prints
    -0/1/2                info/debug/trace
    --<loglevel>          set log level
    
EOM
   exit(0);
} ## end sub help
1;
