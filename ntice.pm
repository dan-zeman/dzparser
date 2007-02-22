# Modul s funkcemi umo��uj�c�mi vyu��t p�i parsingu model n-tic vedle sebe le��c�ch slov.
package ntice;
require 5.000;
require Exporter;
use vystupy;



#------------------------------------------------------------------------------
# U�en� n-tic. Projde v�echny n-tice po sob� jdouc�ch slov ve v�t�, zjist�
# jejich morfologick� vzor a zapamatuje si jejich syntaktickou strukturu.
#------------------------------------------------------------------------------
sub ucit
{
    my $n = shift; # jak velk� n-tice se maj� hledat
    # Zat�m glob�ln� prom�nn�.
    my $anot = \@main::anot;
    # Pozd�ji by to mohlo j�t zobecnit na trojice slo�ek, kter� se ocitly vedle
    # sebe v pr�b�hu anal�zy. (P�i tr�ninku znamen� "vedle sebe" d�ti jednoho rodi�e. V�echny d�ti?)
    # Pozor. Prvn� n�st�el po��tal s trojicemi po sob� jdouc�ch slov, kter� v�ak mohly m�t i dvoupatrovou strukturu.
    # Druh� n�pad po��t� s trojicemi (n-ticemi) slov, kter� nemusej� ve v�t� le�et vedle sebe, ale zase to musej� b�t
    # d�ti jednoho rodi�e, tj. struktura je v�dy jednopatrov�. Obecn� DOP model by uvolnil oboj�, tj. jak vzd�lenost
    # slov, tak hloubku struktury. Zat�m ale nev�m, zda a jak je realizovateln�.
    for(my $i = 0; $i<=$#{$anot}-$n+1; $i++)
    {
        # Z�skat morfologick� a syntaktick� vzorec n-tice.
        # Morfologick�m mysl�m posloupnost upraven�ch zna�ek, syntaktick�m posloupnost index� rodi��.
        # U syntaktick�ch je indexem "X", pokud z�vislost vede ven z n-tice, a tak� pokud uzel "vis�"
        # s�m na sob� (nem�lo by se st�t jinde ne� u ko�ene, tj. uzlu s indexem 0).
        my @mvzor = map{$_->{uznacka}}(@{$anot}[$i..$i+$n-1]);
        my @svzor;
        # Spo��tat z�vislosti, kter� vedou ze skupiny ven.
        my $ven;
        for(my $j = 0; $j<$n; $j++)
        {
            my $r = $anot->[$i+$j]{rodic_vzor};
            if($r<$i || $r>$i+$n-1 || $r==$i+$j)
            {
                $svzor[$j] = "X";
                $ven++;
            }
            else
            {
                $svzor[$j] = $r-$i;
            }
        }
        my $mvzor = join(" ", @mvzor);
        my $svzor;
        # Jestli�e ven vede v�ce ne� jedna z�vislost, skupina je roztr�en� a asi nem� smysl se pokou�et
        # n�kdy ji rekonstruovat. I tak si ale mus�me zapamatovat v�skyt mvzoru, proto�e n�m sn�� v�hu
        # t�ch v�skyt�, p�i nich� skupina roztr�en� nebyla.
        if($ven>1)
        {
            $svzor = join(",", map{"X"}[0..$n-1]);
        }
        else
        {
            $svzor = join(",", @svzor);
        }
        # Prom�nn� glob�ln� v r�mci tohoto modulu: %ntice a %priklady.
        # Zapamatovat si v�skyt dan� dvojice vzor�.
        $ntice{$mvzor}{$svzor}++;
        # Jestli�e nezn�me p��klad, zapamatovat si tak� p��klad.
        unless(exists($priklady{$mvzor}))
        {
            $priklady{$mvzor} = join(" ", @{$anot}[$i..$i+$n-1]);
        }
    }
}



#------------------------------------------------------------------------------
# Ulo�� nau�en� vzory n-tic morfologick�ch zna�ek.
#------------------------------------------------------------------------------
sub vypsat
{
    my @mvzory = sort(keys(%ntice));
    print STDERR ("Mame ", $#mvzory+1, " mvzoru.\n");
    for(my $i = 0; $i<=$#mvzory; $i++)
    {
        # Se�adit �e�en� sestupn� podle �etnosti.
        my $svzhsh = $ntice{$mvzory[$i]};
        my @svzory = sort{$svzhsh->{$b}<=>$svzhsh->{$a}}(keys(%{$svzhsh}));
        # Zjistit celkov� po�et v�skyt� n-tice. ��dk�m n-tic�m rad�ji nev��it.
        # Sou�asn� zjistit, zda jeden n�zor na �e�en� dostate�n� p�eva�uje a
        # zda p�eva�uj�c� "�e�en�" nen� p��pad, kdy byla n-tice roztr�ena.
        my $celkem;
        my $max;
        my $jmax;
        for(my $j = 0; $j<=$#svzory; $j++)
        {
            my $tento = $svzhsh->{$svzory[$j]};
            $celkem += $tento;
            if($max eq "" || $tento>$max)
            {
                $max = $tento;
                $jmax = $j;
            }
        }
        next if($celkem<5 || $max/$celkem<0.9 || $svzory[$jmax] !~ m/\d/);
        # Jestli�e n-tice pro�la filtrem, ulo�it si jej� v�stup. Na konci v�stupy se�ad�me a vyp�eme.
        my $vystup = "MVZOR $mvzory[$i]\t\t\t($priklady{$mvzory[$i]})\n";
        for(my $j = 0; $j<=$#svzory; $j++)
        {
            $vystup .= sprintf("    SVZOR %s\t%4d\t%3d %%\n", $svzory[$j], $svzhsh->{$svzory[$j]}, $svzhsh->{$svzory[$j]}*100/$celkem);
        }
        my %zaznam;
        $zaznam{vystup} = $vystup;
        $zaznam{vyznam} = $max;
        push(@vystupy, \%zaznam);
    }
    print STDERR ("Pro vystup zbylo ", $#vystupy+1, " vzoru.\n");
    # Se�adit a vypsat z�znamy.
    @vystupy = sort{$a->{vyznam}<=>$b->{vyznam}}(@vystupy);
    for(my $i = 0; $i<=$#vystupy; $i++)
    {
        vystupy::vypsat("ntice", $vystupy[$i]{vystup});
    }
}



#------------------------------------------------------------------------------
# Na�te nau�en� vzory n-tic morfologick�ch zna�ek.
#------------------------------------------------------------------------------
sub cist
{
    my $soubor = shift;
    # 8.3.2004: Ignoruje se jm�no souboru dodan� volaj�c�m. M�sto toho se
    # postupn� �tou soubory 2ice.txt a� 10ice.txt v aktu�ln� slo�ce.
    my %ntice;
    for(my $i = 2; $i<=10; $i++)
    {
        $soubor = $i."ice.txt";
    open(NTICE, $soubor) or die("Nelze otev��t soubor $soubor: $!\n");
    my $mvzor;
    while(<NTICE>)
    {
        if(m/^MVZOR (.*?)\t/)
        {
        $mvzor = $1;
        }
        elsif(m/SVZOR (.*?)\t/)
        {
        $ntice{$mvzor} = $1;
        # Zajistit, aby se k mvzoru zapsalo pouze prvn� (nejlep��) �e�en�: ostatn� p�esm�rovat do kan�lu.
        $mvzor = "";
        }
    }
    close(NTICE);
    }
    return \%ntice;
}



#------------------------------------------------------------------------------
# Pokus� se na v�tu aplikovat vzory n-tic. Vr�t� ��ste�n� rozebranou v�tu.
# (P�edpokl�d�, �e byla nasazena p�ed v�emi ostatn�mi n�stroji, tj. �e ��dn�
# ��st v�ty je�t� rozebran� nen�.)
#------------------------------------------------------------------------------
sub nasadit
{
    my $ntice = shift; # odkaz na hash
    my $anot = shift; # odkaz na pole hash� s anotacemi jednotliv�ch slov
    my @rodice; # v�stupn� pole
    my @mzn = map{$_->{uznacka}}(@{$anot});
    # P�ednost vzor� p�i konfliktu: zat�m ten, kter� se ve v�t� najde prvn� (tj. nejdel�� vzor, a nebo, pokud jsou stejn� dlouh�, vzor nejv�c vlevo).
    ### M�lo by to b�t sp� tak, �e nej�sp�n�j�� pravidlo m� nejv�t�� p�ednost!
    ### Nebo by se od n-tic m�lo upustit tam, kde jsou v konfliktu.
    for(my $n = 10; $n>=2; $n--)
    {
    for(my $i = 0; $i<=$#mzn-2; $i++)
    {
        my $mvzor = join(" ", @mzn[$i..$i+$n-1]);
        next if(!exists($ntice->{$mvzor}));
        my @svzor = split(",", $ntice->{$mvzor});
        # Ulo�it nalezen� �e�en� do seznamu rodi��.
        for(my $j = 0; $j<=$#svzor; $j++)
        {
        unless($svzor[$j] eq "X")
        {
            # Zapamatovat si konflikty mezi p�ekr�vaj�c�mi se n-ticemi.
                    if($rodice[$i+$j] ne "" && $rodice[$i+$j]!=$i+$svzor[$j])
            {
            $main::ntice_konflikty++;
            }
            else
            {
            $rodice[$i+$j] = $i+$svzor[$j];
            }
        }
        }
    }
    }
    return \@rodice;
}



#------------------------------------------------------------------------------
# Porovn� vzorovou, �plnou a ��ste�nou anal�zu t�e v�ty. P�edpokl�d�, �e
# �pln� anal�za je "p�vodn�" bez n-tic, zat�mco ��ste�n� je "nov�", s n-ticemi.
# Tam, kde se ��ste�n� anal�za uplatnila, zjist�, zda jde o zlep�en� apod.
#------------------------------------------------------------------------------
sub zhodnotit
{
    my $vzor = shift; # odkaz na vzorov� pole index� rodi��
    my $ntc0 = shift; # odkaz na pole index� rodi�� dodan� p�vodn�m parserem
    my $ntc1 = shift; # odkaz na pole index� rodi�� dodan� nov�m parserem
    my $ntc = shift; # odkaz na pole index� rodi�� podle n-tic umo��uje poznat, kde n-tice p��mo zas�hly
    for(my $i = 0; $i<=$#{$ntc1}; $i++)
    {
        if($ntc->[$i] ne "")
        {
            $main::ntice_celkem++;
            my $dobre0 = $ntc0->[$i]==$vzor->[$i];
            my $dobre1 = $ntc1->[$i]==$vzor->[$i];
            my $stejne = $ntc1->[$i]==$ntc0->[$i];
            if(!$dobre1 && 0)
            {
                my $anot = \@main::anot;
                print("\n");
                for(my $j = 0; $j<=$#{$anot}; $j++)
                {
                    print("$j:$anot->[$j]{slovo} ");
                }
                print("\n");
                print("i=$i, vzor=$vzor->[$i], ntc0=$ntc0->[$i], ntc1=$ntc1->[$i]\n");
            }
            if($dobre0)
            {
                if($dobre1)
                {
                    $main::ntice_dobre++;
                }
                else
                {
                    $main::ntice_horsi++;
                }
            }
            else
            {
                if($dobre1)
                {
                    $main::ntice_lepsi++;
                }
                elsif($stejne)
                {
                    $main::ntice_stejne_spatne++;
                }
                else
                {
                    $main::ntice_ruzne_spatne++;
                }
            }
        }
        # Tento uzel nebyl zav�en podle modelu n-tic, ale jeho zav�en� mohlo b�t ovlivn�no
        # novou situac�, kter� po ��ste�n�m rozboru v�ty pomoc� n-tic nastala.
        else
        {
            $main::ntice_neprimo++;
            my $dobre0 = $ntc0->[$i]==$vzor->[$i];
            my $dobre1 = $ntc1->[$i]==$vzor->[$i];
            my $stejne = $ntc1->[$i]==$ntc0->[$i];
            if($dobre0)
            {
                if($dobre1)
                {
                    $main::ntice_neprimo_dobre++;
                }
                else
                {
                    $main::ntice_neprimo_horsi++;
                }
            }
            else
            {
                if($dobre1)
                {
                    $main::ntice_neprimo_lepsi++;
                }
                elsif($stejne)
                {
                    $main::ntice_neprimo_stejne_spatne++;
                }
                else
                {
                    $main::ntice_neprimo_ruzne_spatne++;
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Vytvo�� hl�en� na z�klad� sv�ch statistik. Nikam ho nevypisuje, jen ho vr�t�
# volaj�c�mu. Je na volaj�c�m, aby rozhodl, na kter� v�stup ho po�le.
#------------------------------------------------------------------------------
sub vytvorit_hlaseni
{
    my $hlaseni = "------- Model n-tic -------\n";
    $hlaseni .= sprintf("%7d   rozhodnut�ch slov\n", $main::ntice_celkem);
    $hlaseni .= sprintf("%7d   konflikt� mezi p�ekr�vaj�c�mi se n-ticemi\n", $main::ntice_konflikty);
    $hlaseni .= sprintf("%7d   zlep�en� oproti p�vodn�mu modelu\n", $main::ntice_lepsi);
    $hlaseni .= sprintf("%7d   zhor�en� oproti p�vodn�mu modelu\n", $main::ntice_horsi);
    $hlaseni .= sprintf("%7d   stejn� dobr�ch jako p�vodn� model\n", $main::ntice_dobre);
    $hlaseni .= sprintf("%7d   stejn� �patn�ch jako p�vodn� model\n", $main::ntice_stejne_spatne);
    $hlaseni .= sprintf("%7d   jin�ch ne� p�vodn� model, ale tak� �patn�ch\n", $main::ntice_ruzne_spatne);
    $hlaseni .= sprintf("%7d   slov mimo n-tice\n", $main::ntice_neprimo);
    $hlaseni .= sprintf("%7d   nep��m�ch zlep�en� oproti p�vodn�mu modelu\n", $main::ntice_neprimo_lepsi);
    $hlaseni .= sprintf("%7d   nep��m�ch zhor�en� oproti p�vodn�mu modelu\n", $main::ntice_neprimo_horsi);
    $hlaseni .= sprintf("%7d   nep��mo stejn� dobr�ch jako p�vodn� model\n", $main::ntice_neprimo_dobre);
    $hlaseni .= sprintf("%7d   nep��mo stejn� �patn�ch jako p�vodn� model\n", $main::ntice_neprimo_stejne_spatne);
    $hlaseni .= sprintf("%7d   nep��mo jin�ch ne� p�vodn� model, ale tak� �patn�ch\n", $main::ntice_neprimo_ruzne_spatne);
    return $hlaseni;
}



1;
