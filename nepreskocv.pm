# Funkce souvisej�c� se subkategorizac� sloves.
package nepreskocv;
use zakaz;



#------------------------------------------------------------------------------
# Na�te seznam z�kaz� p�esko�en� slovesa.
#------------------------------------------------------------------------------
sub cist
{
    my $jmeno_souboru = shift;
    my %zakazy; # v�stupn� hash; kl��: zna�kaSlovesa zna�ka� zna�kaZ
    open(ZAKAZY, $jmeno_souboru) or die("Nelze otevrit soubor $jmeno_souboru se seznamem zakazu preskoceni slovesa: $!\n");
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
# Najde v konkr�tn� v�t� potenci�ln� z�vislosti, kter� maj� b�t zak�z�ny.
# Na z�klad� n�lezu aktualizuje seznam zak�zan�ch hran, kter� dostane.
#------------------------------------------------------------------------------
sub najit_ve_vete
{
    my $zakazy = shift; # odkaz na hash
    my $anot = shift; # odkaz na pole hash�
    my $zakaz = shift; # skal�r s dosavadn�m seznamem z�kaz�
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
                    # Bylo zji�t�no, �e mezi i a j le�� sloveso, kter� nesm� b�t p�esko�eno.
                    # P�idat z�vislost i-j mezi zak�zan�.
                    zakaz::pridat_zakaz(\$zakaz, $i, $j, "nelze preskocit $k");
                }
            }
        }
    }
    return $zakaz;
}



1;
