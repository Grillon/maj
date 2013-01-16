#!/bin/ksh
function lance
{
echo "fonction non implementee"
exit 253
}
############FONCTION VERROU##############
function verrouSauve
{
touch "${vRep}/${vSauve}";
if [ $? -ne 0 ];then
        echo "echec de creation de verrou sauve";
        exit 254;
fi
}
function verifSauv
{
#un si present et 0 si absent;
if [ -a "${vRep}/${vSauve}" ];then
        return 1;
else return 0;
fi
}

############FONCTION VERIF LVM##############
function verifLV
{
while [ "${i}" -le "${nbrlv}" ];do
        lv="$(eval echo \$lv${i})";
        if [ ! -a ${lv} ];then
                retrun 1;
        fi
done
return 0;
}
############FONCTIONS D'ACTION##############
function sauve
{
if [ "$(verifLV)" -ne 0 ];then
        echo "l'un des lv de la conf est inexistant";
        exit 254;
fi
while [ "${i}" -le "${nbrlv}" ];do
        lv="$(eval echo \$lv${i})";
        lvsplit -s _back /dev/${vg}/${lv};
        if [ $? -e 0 ];then
                fsck /dev/${vg}/${lv}_back;
        else
                echo "echec du split ${lv}, lancer valide pour retour arriere si d'autres LV ont ete splite";
                exit 254;
        fi
done
}
function valide
{
if [ "$(verifLV)" -ne 0 ];then
        echo "l'un des lv de la conf est inexistant";
        exit 254;
fi
if [ "$(verifSauve)" -e 0 ];then
        echo "verrou sauve inexistant";
        exit 254;
fi
while [ "${i}" -le "${nbrlv}" ];do
        lv_source="$(eval echo \$lv${i})";
        lv_dest="${lv_source}_back"
        lvmerge /dev/${vg}/${lv_dest} /dev/${vg}/${lv_source}
        if [ $? -e 0 ];then
                fsck /dev/${vg}/${lv_dest};
        else
                echo "echec du merge vers ${lv_dest}";
                exit 254;
        fi
done
rm ${vSauve}
}
function retour
{
if [ "$(verifLV)" -ne 0 ];then
        echo "l'un des lv de la conf est inexistant";
        exit 254;
fi
if [ "$(verifSauve)" -e 0 ];then
        echo "verrou sauve inexistant";
        exit 254;
fi
while [ "${i}" -le "${nbrlv}" ];do
        lv_dest="$(eval echo \$lv${i})";
        lv_source="${lv_source}_back"
        lvmerge /dev/${vg}/${lv_source} /dev/${vg}/${lv_dest}
        if [ $? -e 0 ];then
                fsck /dev/${vg}/${lv_dest};
                mv /dev/${vg}/r${lv_source} /dev/${vg}/r${lv_dest}
                mv /dev/${vg}/${lv_source} /dev/${vg}/${lv_dest}
        else
                echo "echec du merge vers ${lv_dest}";
                exit 254;
        fi
done
rm ${vSauve}
}
function creation
{
echo creation
i=1;
if [ -a "${vRep}/${vCreation}" ];then
        echo "environnement deja en place sinon supprimer le verrou ${vRep}/${vCreation}";
        exit 254;
fi
while [ "${i}" -le "${tnbrlv}" ];do
        #preparation FS
        ptm="$(eval echo \$tfs${i})";
        if [ ! -d ${ptm} ];then
                echo $ptm;
                mkdir $ptm;
        fi
        #preparation LV
        lv="$(eval echo \$tlv${i})";
        lvcreate -n $lv -l 1 $tvg;
        if [ $? -ne 0 ];then
                echo "$? : echec de creation du lv $lv";
        else lvextend -m 1 /dev/${tvg}/${lv};
        newfs /dev/${tvg}/r${lv};
        mount /dev/${tvg}/${lv} $ptm;
        fi
        i=$((i+1));
done
touch "${vRep}/${vCreation}";
if [ $? -ne 0 ];then
        echo "echec de creation de creation verrou";
        exit 254;
fi
}
function suppression
{
echo "suppression de l'environnement de test"
i=1;
if [ ! -a "${vRep}/${vCreation}" ];then
        echo "environnement inexistant sinon veuillez creer le verrou : ${vRep}/${vCreation}"
        exit 254
fi
while [ "${i}" -le "${tnbrlv}" ];do
        #preparation FS
        ptm="$(eval echo \$tfs${i})"
        if [ ! -d ${ptm} ];then
                echo $ptm
                echo "repertoire inexistant...Ce n'est pas un ptm"
        fi
        umount ${ptm}
        #preparation LV
        if [ $? -eq 0 ];then
                lv="$(eval echo \$tlv${i})"
                lvremove -f /dev/${tvg}/${lv}
                rmdir ${ptm};
        else echo "$? : echec demontage du fs ${ptm}"
        fi
        i=$((i+1))
done
rm "${vRep}/${vCreation}";
}
function usage
{
        echo "$0 -lance | -sauve | -valide | -retour | -creation | -suppression (pour env de test)";
}
if [ $# -ne 1 ];then
        usage
        exit 251
fi
. /tmp/yst/maj.conf
if [[ "${1%${1#?}}" != "-" ]];then
        echo "argument incorrect"
        usage;
        exit 251;
fi
arg="${1#?}"
if [ ${arg} = "lance" ];then
        lance;
elif [ "${arg}" = "sauve" ];then
        sauve;
elif [ "${arg}" = "valide" ];then
        valide;
elif [ "${arg}" = "retour" ];then
        retour;
elif [ "${arg}" = "creation" ];then
        creation;
elif [ "${arg}" = "suppression" ];then
        suppression;
else
        echo "arg incorrect";
        usage
        exit 251;
fi
echo "fin normale"
exit 0
