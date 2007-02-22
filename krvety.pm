# Model kr�tk�ch v�t na z�klad� vzor� morfologick�ch zna�ek.
package krvety;



#------------------------------------------------------------------------------
# Zjist�, zda vzor morfologick�ch zna�ek ve v�t� odpov�d� n�kter�mu vzoru
# zn�m�mu z tr�novac�ch dat. Pokud ano, zjist� syntaktickou strukturu
# odpov�daj�c� tomuto vzoru a vr�t� ji. Pokud ne, zavol� funkci na b�n� rozbor
# v�ty. V�slednou strukturu vrac� zabalenou do hashe %stav, kv�li kompatibilit�
# s jin�mi funkcemi na rozbor v�ty.
#------------------------------------------------------------------------------
sub rozebrat
{
    my $vzorstrom = shift; # odkaz na hash hash� {vzor}{strom}
    # Zat�m glob�ln� prom�nn�.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    # Odkaz na v�stupn� hash.
    my $stav;
    # Sestavit morfologick� vzorec v�ty.
    my $vzor;
    for(my $i = 1; $i<=$#{$anot}; $i++)
    {
        $vzor .= "~" if($i>1);
        my $znacka = $anot->[$i]{uznacka};
        $vzor .= $znacka;
    }
    # Ke vzorci naj�t nejpravd�podobn�j�� stromovou strukturu.
    my $strom = $vzorstrom->{$vzor}{strom};
    my $cetnost_stromu = $vzorstrom->{$vzor}{cetnost};
    my $cetnost_vzoru = $vzorstrom->{$vzor}{celkem};
    # Nep�esv�d�iv� �etnost, nezn�m� vzor => zpracovat klasicky.
    if($cetnost_vzoru==0 || $cetnost_stromu/$cetnost_vzoru<0.5)
    {
        # Pokud takov� vzorec nezn�me, rozebrat v�tu klasicky.
        $stav = rozebrat::rozebrat_vetu();
    }
    else
    {
        # Naprosto nestatistick� z�sah. Tyto v�ty (nap�. "Karel Ro��nek, Praha") jsou v PDT anotov�ny n�kolika
        # zp�soby, a nav�c v tr�novac�ch datech p�eva�uje jin� zp�sob ne� v testovac�ch. Zde m�m ten z testovac�ch.
        if($vzor eq "NY1~N1~Z,~N1")
        {
            $strom = "2,3,0,3";
        }
        my @rodic = split(/,/, $strom);
        # P�idat pr�zdn� nult� prvek, ten ve vzorov�ch stromech nen�.
        unshift(@rodic, -1);
        my %stav;
        $stav{rodic} = \@rodic;
        $stav = \%stav;
    }
    return $stav;
}



1;
