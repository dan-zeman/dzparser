# Funkce související se subkategorizací sloves.
package nepreskocv;
use utf8;
use zakaz;



#------------------------------------------------------------------------------
# Načte seznam zákazů přeskočení slovesa.
#------------------------------------------------------------------------------
sub cist
{
    my $jmeno_souboru = shift;
    my %zakazy; # výstupní hash; klíč: značkaSlovesa značkaŘ značkaZ
    open(ZAKAZY, $jmeno_souboru) or die("Nelze otevrit soubor $jmeno_souboru se seznamem zakazu preskoceni slovesa: $!\n");
    binmode(ZAKAZY, ":encoding(iso-8859-2)");
    while(<ZAKAZY>)
    {
        chomp;
        if(m/\S+ \S+ \S+/)
        {
            $zakazy{$&}++;
        }
    }
    close(ZAKAZY);
    return \%zakazy;
}



#------------------------------------------------------------------------------
# Najde v konkrétní větě potenciální závislosti, které mají být zakázány.
# Na základě nálezu aktualizuje seznam zakázaných hran, který dostane.
#------------------------------------------------------------------------------
sub najit_ve_vete
{
    my $zakazy = shift; # odkaz na hash
    my $anot = shift; # odkaz na pole hashů
    my $zakaz = shift; # skalár s dosavadním seznamem zákazů
    for(my $i = 0; $i<=$#{$anot}; $i++)
    {
        for(my $j = 0; $j<=$#{$anot}; $j++)
        {
            my($k0, $k1);
            if($i<$j)
            {
                $k0 = $i;
                $k1 = $j;
            }
            else
            {
                $k0 = $j;
                $k1 = $i;
            }
            for(my $k = $k0+1; $k<$k1; $k++)
            {
                my $zaznam = "$anot->[$k]{uznacka} $anot->[$i]{uznacka} $anot->[$j]{uznacka}";
                if(#$anot->[$k]{uznacka} =~ m/^V/ &&
                   exists($zakazy->{$zaznam}))
                {
                    # Bylo zjištěno, že mezi i a j leží sloveso, které nesmí být přeskočeno.
                    # Přidat závislost i-j mezi zakázané.
                    zakaz::pridat_zakaz(\$zakaz, $i, $j, "nelze preskocit $k");
                }
            }
        }
    }
    return $zakaz;
}



1;
