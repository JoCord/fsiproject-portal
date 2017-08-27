sub help {
   print <<EOM;

             ${colorBold}H E L P for $prgname ${colorNoBold}

  ${colorGreen}VI Clone & Management${colorNormal}
  
    ${colorRed}VM to handle${colorNormal}
     --vm <vmname>           work with this vm
    
    ${colorRed}Clone parameter${colorNormal}
     --optvm <option flag>   additional info on clone vm
                             (no space allowed)
     --storage <name>        alternative storage to clone
    
    ${colorRed}System parameter${colorNormal}
     --debug                 debug mode
     --reboot                reboot only vm
     --noemail               send no email
     --chkon [boot]          check if vm online (if given boot)
     --ignore                ignore pid files
    
EOM
   exit(0);
} ## end sub help

1;
