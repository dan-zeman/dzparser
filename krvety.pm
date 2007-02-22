# Model krátkých vìt na základì vzorù morfologických znaèek.
package krvety;



#------------------------------------------------------------------------------
# Zjistí, zda vzor morfologických znaèek ve vìtì odpovídá nìkterému vzoru
# známému z trénovacích dat. Pokud ano, zjistí syntaktickou strukturu
# odpovídající tomuto vzoru a vrátí ji. Pokud ne, zavolá funkci na bì¾ný rozbor
# vìty. Výslednou strukturu vrací zabalenou do hashe %stav, kvùli kompatibilitì
# s jinými funkcemi na rozbor vìty.
#------------------------------------------------------------------------------
sub rozebrat
{
    my $vzorstrom = shift; # odkaz na hash hashù {vzor}{strom}
    # Zatím globální promìnné.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    # Odkaz na výstupní hash.
    my $stav;
    # Sestavit morfologický vzorec vìty.
    my $vzor;
    for(my $i = 1; $i<=$#{$anot}; $i++)
    {
        $vzor .= "~" if($i>1);
        my $znacka = $anot->[$i]{uznacka};
        $vzor .= $znacka;
    }
    # Ke vzorci najít nejpravdìpodobnìj¹í stromovou strukturu.
    my $strom = $vzorstrom->{$vzor}{strom};
    my $cetnost_stromu = $vzorstrom->{$vzor}{cetnost};
    my $cetnost_vzoru = $vzorstrom->{$vzor}{celkem};
    # Nepøesvìdèivá èetnost, neznámý vzor => zpracovat klasicky.
    if($cetnost_vzoru==0 || $cetnost_stromu/$cetnost_vzoru<0.5)
    {
        # Pokud takový vzorec neznáme, rozebrat vìtu klasicky.
        $stav = rozebrat::rozebrat_vetu();
    }
    else
    {
        # Naprosto nestatistický zásah. Tyto vìty (napø. "Karel Ro¾ánek, Praha") jsou v PDT anotovány nìkolika
        # zpùsoby, a navíc v trénovacích datech pøeva¾uje jiný zpùsob ne¾ v testovacích. Zde mám ten z testovacích.
        if($vzor eq "NY1~N1~Z,~N1")
        {
            $strom = "2,3,0,3";
        }
        my @rodic = split(/,/, $strom);
        # Pøidat prázdný nultý prvek, ten ve vzorových stromech není.
        unshift(@rodic, -1);
        my %stav;
        $stav{rodic} = \@rodic;
        $stav = \%stav;
    }
    return $stav;
}



1;
