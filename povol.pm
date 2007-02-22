package povol;



#------------------------------------------------------------------------------
# Podle nastavené konfigurace vybere funkci, která umí k libovolnému rozpraco-
# vanému stromu øíct, které závislosti do nìj lze v pøí¹tím kroku pøidat.
#------------------------------------------------------------------------------
sub zjistit_povol
{
    my $konfig = \%main::konfig;
    if($konfig->{neproj})
    {
        my $rodic = shift;
        my $anot = \@main::anot;
        return povolit_rematizator_za_predlozku($anot, $rodic);
    }
    else
    {
        if($konfig->{komponentove})
        {
            return zjistit_povol_komponentove(@_);
        }
        else
        {
            return zjistit_povol_shora_dolu(@_);
        }
    }
}



#------------------------------------------------------------------------------
# Pro libovolný neúplný strom zjistí, které závislosti je do nìj mo¾né pøidat,
# ani¾ by naru¹ily projektivitu. Strom se pøedává v parametrech jako seznam
# odkazù na rodièe. Funkce vrací seznam povolených hran (pole, ne øetìzec!).
#------------------------------------------------------------------------------
sub zjistit_povol_komponentove
{
    my $rodic = shift; # odkaz na pole indexù rodièù uzlù
    my @povol; # výstupní pole
    # Pøes $i projít uzly, které lze zavìsit, proto¾e je¹tì nemají rodièe.
    # Vynechat uzel è. 0, to bude ka¾dopádnì koøen.
    for(my $i = 1; $i<=$#{$rodic}; $i++)
    {
        if($rodic->[$i]==-1 || $rodic->[$i] eq "")
        {
            # Vyhledat mezi sousedy uzlu jeho mo¾né rodièe.
            # Sousedé vlevo.
            # Zatím nevíme, jestli soused vlevo nezávisí na mì.
            my $nejdale = $i-1;
            my @mozna_povol;
            for(my $j = $nejdale; $j!=-1 && $j ne ""; $j = $rodic->[$j])
            {
                $nejdale = $j if($j<$nejdale);
                if($j==$i)
                {
                    # Smùla. Zatím jsem se pohyboval ve svém podstromu.
                    splice(@mozna_povol);
                    $j = $nejdale-1;
                    $nejdale = $j;
                }
                push(@mozna_povol, "$j-$i");
            }
            # OK, vypadli jsme na sirotkovi, teï je v @mozna_povol to, co je
            # opravdu dovoleno.
            splice(@povol, $#povol+1, 0, @mozna_povol);
            # Sousedé vpravo.
            if($i<$#{$rodic})
            {
                $nejdale = $i+1;
                splice(@mozna_povol);
                for(my $j = $nejdale; $j!=-1 && $j ne ""; $j = $rodic->[$j])
                {
                    $nejdale = $j if($j>$nejdale);
                    if($j==$i)
                    {
                        # Smùla. Zatím jsem se pohyboval ve svém podstromu.
                        splice(@mozna_povol);
                        $j = $nejdale+1;
                        # Pozor na pravý okraj vìty!
                        last if($j>$#{$rodic});
                        $nejdale = $j;
                    }
                    push(@mozna_povol, "$j-$i");
                }
                # OK, vypadli jsme na sirotkovi, teï je v @mozna_povol to, co
                # je opravdu dovoleno.
                splice(@povol, $#povol+1, 0, @mozna_povol);
            }
        }
    }
    return @povol;
}



#------------------------------------------------------------------------------
# Zjistí, které závislosti lze pøidat do stromu, aby byl zachován postup shora
# dolù. Pozor, na rozdíl od komponentové, tato verze nehlídá projektivitu
# stromu!
#------------------------------------------------------------------------------
sub zjistit_povol_shora_dolu
{
    my $rodic = shift; # odkaz na rozpracovaný strom
    my @povol; # výstupní pole
    # Povolené jsou závislosti uzlù, které je¹tì ve stromu nejsou, na uzlech,
    # které ji¾ ve stromu jsou.
    for(my $i = 0; $i<=$#{$rodic}; $i++)
    {
        if($i==0 || $rodic->[$i]>=0)
        {
            for(my $j = 1; $j<=$#{$rodic}; $j++)
            {
                if($rodic->[$j]==-1)
                {
                    push(@povol, "$i-$j");
                }
            }
        }
    }
#    print(join(",", @{$rodic}), "\n");
#    print(join(",", @povol), "\n");
    return @povol;
}



#------------------------------------------------------------------------------
# Zjistí, zda urèitá závislost je povolená. Pokud dostane odkaz na seznam
# povolených závislostí, pouze projde tento seznam. Jinak si ho nejdøív sama
# zjistí podle globální promìnné @rodic.
#------------------------------------------------------------------------------
sub je_povoleno
{
    my $r = $_[0];
    my $z = $_[1];
    my $povolref = $_[2];
    my @povol;
    if(!$povolref)
    {
        @povol = zjistit_povol(@rodic);
        $povolref = \@povol;
    }
    for(my $i = 0; $i<=$#{$povolref}; $i++)
    {
        if($povolref->[$i] eq "$r-$z")
        {
            return 1;
        }
    }
    return 0;
}



#==============================================================================
# NEPROJEKTIVITY
#==============================================================================



#------------------------------------------------------------------------------
# Naète seznam rematizátorù. Podle nich se dají poznat neprojektivity typu
# rematizátor - pøedlo¾ka - slovo visící na pøedlo¾ce a øídící rematizátor.
#------------------------------------------------------------------------------
sub cist_rematizatory
{
    open(REM, "rematizatory.txt") or die("Nelze otevrit rematizatory: $!\n");
    while(<REM>)
    {
        if(m/^\S+ \d+ \d+ (\S+)/)
        {
            $rematizatory{$1} = 1;
        }
    }
    close(REM);
}



#------------------------------------------------------------------------------
# Povolí neprojektivní závislosti rematizátorù na slovech za pøedlo¾kou nad
# rámec toho, co dovoluje modul povol. Podmínkou je, ¾e je¹tì nebyla naru¹ena
# situace, která neprojektivity zpùsobuje, tj. pøedev¹ím rematizátor je¹tì nemá
# rodièe, dále pøedlo¾ka nevisí ani na rematizátoru, ani na slovì za ní.
#------------------------------------------------------------------------------
sub povolit_rematizator_za_predlozku
{
    my $anot = shift;
    my $rodic = shift; # rozpracovaný strom
    my @povol = povolit_infinitivy($anot, $rodic);
    for(my $i = 0; $i<$#{$anot}; $i++)
    {
        # Kvùli obavì z cyklù radìji po¾adovat, aby uzel za pøedlo¾kou byl
        # pøipojen nanejvý¹ na pøedlo¾ku a pøedlo¾ka aby je¹tì rodièe nemìla vùbec.
        if(exists($rematizatory{$anot->[$i]{slovo}}) &&
           $anot->[$i+1]{znacka} =~ m/^R/ &&
           $rodic->[$i] == -1 &&
           $rodic->[$i+1] == -1 &&
           ($rodic->[$i+2] == -1 || $rodic->[$i+2] == $i+1))
        {
            push(@povol, ($i+2)."-".$i);
        }
    }
    return @povol;
}



#------------------------------------------------------------------------------
# Povolí neprojektivní závislosti na infinitivech, pokud infinitiv visí na svém
# levém sousedovi a neprojektivita podlézá pouze tohoto souseda a uzly, které
# u¾ na nìm visí (pøesnì øeèeno, povolíme, aby na infinitivu viselo navíc v¹e,
# co mù¾e viset na jeho rodièi.
#------------------------------------------------------------------------------
sub povolit_infinitivy
{
    my $anot = shift;
    my $rodic = shift; # rozpracovaný strom
    my @povol = povolit_li($anot, $rodic);
    for(my $i = 1; $i<=$#{$anot}; $i++)
    {
        if($anot->[$i]{uznacka} =~ m/^Vf/ &&
           $rodic->[$i]==$i-1)
        {
            # Povolit v¹em uzlùm, které mohou zleva viset na uzlu nalevo od
            # infinitivu, aby visely i na infinitivu samotném.
            for(my $j = 0; $j<=$#povol; $j++)
            {
                $povol[$j] =~ m/^(\d+)-(\d+)$/;
                my $r = $1;
                my $z = $2;
                if($r==$i-1 && $z<$r)
                {
                    push(@povol, "$i-$z");
                }
            }
        }
    }
    return @povol;
}



#------------------------------------------------------------------------------
# Povolí neprojektivní závislosti pøes -li a v¹ak.
#------------------------------------------------------------------------------
sub povolit_li
{
    my $anot = shift;
    my $rodic = shift; # rozpracovaný strom
    my @povol = zjistit_povol_komponentove($rodic);
    for(my $i = 1; $i<=$#{$anot}; $i++)
    {
        if($anot->[$i]{slovo} eq "li" &&
           $anot->[$i-1]{slovo} eq "-" &&
           $i>2)
        {
            # Povolit v¹em uzlùm, které mohou zprava viset na li, aby visely i
            # na slovì pøed pomlèkou.
            for(my $j = 0; $j<=$#povol; $j++)
            {
                $povol[$j] =~ m/^(\d+)-(\d+)$/;
                my $r = $1;
                my $z = $2;
                if($r==$i && $z>$r)
                {
                    push(@povol, ($i-2)."-$z");
                }
            }
        }
        elsif($anot->[$i]{slovo} eq "v¹ak" && $i>1 && $i<$#{$anot})
        {
            # Povolit v¹em uzlùm, které mohou zleva viset na v¹ak, aby visely i
            # na jeho pravém sousedovi, a v¹em uzlùm, které mohou na v¹ak viset
            # zprava, aby visely i na jeho levém sousedovi.
            for(my $j = 0; $j<=$#povol; $j++)
            {
                $povol[$j] =~ m/^(\d+)-(\d+)$/;
                my $r = $1;
                my $z = $2;
                if($r==$i)
                {
                    if($z<$i)
                    {
                        # Pozor, mohl by vzniknout cyklus! Napø. pokud je "v¹ak" na pozici
                        # 2 a u¾ minule bylo pøeskoèeno závislostí 3-1, nesmíme teï bezhlavì
                        # dovolit závislost 1-3!
                        my $ok = 1;
                        for(my $k = $i+1; $k>0; $k = $rodic->[$k])
                        {
                            if($k==$z)
                            {
                                $ok = 0;
                                last;
                            }
                        }
                        if($ok)
                        {
                            push(@povol, ($i+1)."-$z");
                        }
                    }
                    else
                    {
                        # Pozor, mohl by vzniknout cyklus! Napø. pokud je "v¹ak" na pozici
                        # 2 a u¾ minule bylo pøeskoèeno závislostí 3-1, nesmíme teï bezhlavì
                        # dovolit závislost 1-3!
                        my $ok = 1;
                        for(my $k = $i-1; $k>0; $k = $rodic->[$k])
                        {
                            if($k==$z)
                            {
                                $ok = 0;
                                last;
                            }
                        }
                        if($ok)
                        {
                            push(@povol, ($i-1)."-$z");
                        }
                    }
                }
            }
        }
    }
    return @povol;
}



1;
