# Modul s funkcemi umo��uj�c�mi vyu��t p�i parsingu model n-tic vedle sebe le��c�ch slov.
package plodnost;
require 5.000;
require Exporter;
use vystupy;



#------------------------------------------------------------------------------
# U�en� plodnosti. Projde v�tu, zjist� po�et d�t� jednotliv�ch uzl�, vygeneruje
# p��slu�n� ud�losti a zap�e je do centr�ln� evidence.
#------------------------------------------------------------------------------
sub ucit
{
    my $anot = shift; # odkaz na pole hash� s anotacemi slov
    my @n_deti;# = map{0}(0..$#{$anot});
    # Zjistit, kolik m� kter� uzel d�t�.
    for(my $i = 0; $i<=$#{$anot}; $i++)
    {
        my $rodic = $anot->[$i]{rodic_vzor};
        if($rodic>=0) # m��e to b�t i -1
        {
            $n_deti[$rodic]++;
        }
    }
    # Proj�t nas��tan� po�ty d�t� a ulo�it v�skyt ka�d�ho p��padu.
    for(my $i = 0; $i<=$#n_deti; $i++)
    {
        my $udalost = "ZPL ".$anot->[$i]{uznacka}." ".$n_deti[$i];
        # Kontrola podez�el�ch ud�lost�.
        if($udalost eq "ZPL Z?K 1")
        {
            print(join(" ", map{$_->{slovo}."/".$_->{uznacka}."/".$_->{rodic_vzor}}(@{$anot})), "\n");
            print(join(" ", @n_deti), "\n");
            die;
        }
        # Zavolat ud() v hlavn�m modulu, p�edpokl�d�me, �e je to train.pl.
        # Nem��eme p�istupovat p��mo do hashe, proto�e {uznacka} by ve skute�nosti
        # mohl b�t seznam zna�ek ud() to vy�e��. Lep�� by bylo p�esunout ud()
        # do samostatn�ho modulu, ale pozor, tr�novac� ud() nen� tot� co ud()
        # pro parsing!
        main::ud($udalost);
    }
}



#------------------------------------------------------------------------------
# Na�te nau�en� plodnosti zna�ek. Vzhledem k tomu, �e u�en� prob�halo v r�mci
# standardn�ho tr�ninku, mohli bychom k plodnostem p�istupovat do standardn�
# statistiky, ale tady je m�me trochu p�ed�v�kan� a jsou v nich zahrnuty pouze
# zna�ky, kter� d�vaj� p�ednost ur�it�mu po�tu d�t� alespo� v 50 %.
#------------------------------------------------------------------------------
sub cist
{
    open(PLODNOST, "plodnost.txt") or die("Nelze otevrit plodnost: $!\n");
    while(<PLODNOST>)
    {
        if(m/^(\S+) (\d+) (\S+)/ && $3>0.5)
        {
            $plodnost{$1}{nd} = $2;
            $plodnost{$1}{p} = $3;
        }
    }
    close(PLODNOST);
}



#------------------------------------------------------------------------------
# Projde v�echny ud�losti typu ZPL v centr�ln� statistice. Sestav� z nich
# tabulku, kter� pro ka�dou m-zna�ku a dan� po�et d�t� �ekne, jak� je pravd�-
# podobnost, �e uzel, kter� m� tuto m-zna�ku a byl mu ji� d�n doty�n� po�et
# d�t�, dostane je�t� dal�� d�t�.
#------------------------------------------------------------------------------
sub pripravit_ffm
{
    my $stat = shift; # odkaz na hash s centr�ln� statistikou
    # Naj�t v centr�ln� evidenci p��slu�n� ud�losti.
    my %plodnost;
    while(my ($udalost, $pocet) = each(%{$stat}))
    {
        if($udalost =~ m/^ZPL (\S+) (\d+)/)
        {
            my $znacka = $1;
            my $ndeti = $2;
            $ndeti = 3 if($ndeti>3);
            $plodnost{$znacka}[$ndeti] += $pocet;
        }
    }
    # Proj�t jednotliv� zna�ky a sestavit si pro n� tabulky.
    while(my ($znacka, $plodnost) = each(%plodnost))
    {
        # Zjistit celkov� po�et v�skyt� zna�ky.
        my $n_vyskytu;
        for(my $i = 0; $i<=$#{$plodnost}; $i++)
        {
            $n_vyskytu += $plodnost->[$i];
        }
        # Vypo��tat pravd�podobnost pro ka�d� zv��en� po�tu d�t�.
        for(my $i = 0; $i<=3; $i++)
        {
            # Zjistit �etnosti vy���ho ne� aktu�ln�ho po�tu d�t�.
            my $n_vyssi;
            for(my $j = $i+1; $j<=3; $j++)
            {
                $n_vyssi += $plodnost->[$j];
            }
            my $jmenovatel = $n_vyssi+$plodnost->[$i];
            $xxx{$znacka}[$i] = $jmenovatel ? $n_vyssi/$jmenovatel : 0.5;
        }
    }
}



#------------------------------------------------------------------------------
# Ohodnot� pravd�podobnost, �e uzel, kter� m� nyn� n d�t� jich m� m�t v�ce ne�
# n. V�sledek je ��slo z uzav�en�ho intervalu <0;1>.
#------------------------------------------------------------------------------
sub ohodnotit
{
    my $znacka = shift;
    my $dosn = shift; # dosavadn� po�et d�t�
    my $konfig = \%main::konfig;
    if($konfig->{plodnost_model} eq "ffm")
    {
        if($dosn>=3)
        {
            return 0.5;
        }
        else
        {
            return $xxx{$znacka}[$dosn];
        }
    }
    else # tfm nebo qfm
    {
        # Jestli�e zna�ka ned�v� jasnou p�ednost ur�it�mu po�tu d�t�, vr�tit 0.5.
        if($plodnost{$znacka}{p}<0.8)
        {
            if($konfig->{plodnost_model} eq "tfm")
            {
                return 0.5;
            }
            else # qfm
            {
                return 1;
            }
        }
        # Jestli�e u� byl dosa�en nebo p�ekro�en up�ednost�ovan� po�et, vr�tit 0.
        if($dosn>=$plodnost{$znacka}{nd})
        {
            return 0;
        }
        # Jestli�e up�ednost�ovan� po�et je�t� nebyl dosa�en, vr�tit 1.
        # (Nikdy nen� takto siln� (80%) up�ednost�ov�n po�et 3 nebo vy���, tak�e
        # nemus�me m�t strach, �e n�jak�mu uzlu schv�l�me neomezen� po�et d�t�.)
        return 1;
    }
}



1;
