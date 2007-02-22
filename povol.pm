package povol;
use utf8;



#------------------------------------------------------------------------------
# Podle nastavené konfigurace vybere funkci, která umí k libovolnému rozpraco-
# vanému stromu říct, které závislosti do něj lze v příštím kroku přidat.
#------------------------------------------------------------------------------
sub zjistit_povol
{
    my $anot = shift; # odkaz na pole hashů
    my $rodic = shift;
    my $konfig = \%main::konfig;
    if($konfig->{neproj})
    {
        return povolit_rematizator_za_predlozku($anot, $rodic);
    }
    else
    {
        if($konfig->{komponentove})
        {
            return zjistit_povol_komponentove($rodic);
        }
        else
        {
            return zjistit_povol_shora_dolu($rodic);
        }
    }
}



#------------------------------------------------------------------------------
# Pro libovolný neúplný strom zjistí, které závislosti je do něj možné přidat,
# aniž by narušily projektivitu. Strom se předává v parametrech jako seznam
# odkazů na rodiče. Funkce vrací seznam povolených hran (pole, ne řetězec!).
#------------------------------------------------------------------------------
sub zjistit_povol_komponentove
{
    my $rodic = shift; # odkaz na pole indexů rodičů uzlů
    my @povol; # výstupní pole
    # Přes $i projít uzly, které lze zavěsit, protože ještě nemají rodiče.
    # Vynechat uzel č. 0, to bude každopádně kořen.
    for(my $i = 1; $i<=$#{$rodic}; $i++)
    {
        if($rodic->[$i]==-1 || $rodic->[$i] eq "")
        {
            # Vyhledat mezi sousedy uzlu jeho možné rodiče.
            # Sousedé vlevo.
            # Zatím nevíme, jestli soused vlevo nezávisí na mě.
            my $nejdale = $i-1;
            my @mozna_povol;
            for(my $j = $nejdale; $j!=-1 && $j ne ""; $j = $rodic->[$j])
            {
                $nejdale = $j if($j<$nejdale);
                if($j==$i)
                {
                    # Smůla. Zatím jsem se pohyboval ve svém podstromu.
                    splice(@mozna_povol);
                    $j = $nejdale-1;
                    $nejdale = $j;
                }
                push(@mozna_povol, "$j-$i");
            }
            # OK, vypadli jsme na sirotkovi, teď je v @mozna_povol to, co je
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
                        # Smůla. Zatím jsem se pohyboval ve svém podstromu.
                        splice(@mozna_povol);
                        $j = $nejdale+1;
                        # Pozor na pravý okraj věty!
                        last if($j>$#{$rodic});
                        $nejdale = $j;
                    }
                    push(@mozna_povol, "$j-$i");
                }
                # OK, vypadli jsme na sirotkovi, teď je v @mozna_povol to, co
                # je opravdu dovoleno.
                splice(@povol, $#povol+1, 0, @mozna_povol);
            }
        }
    }
    return @povol;
}



#------------------------------------------------------------------------------
# Zjistí, které závislosti lze přidat do stromu, aby byl zachován postup shora
# dolů. Pozor, na rozdíl od komponentové, tato verze nehlídá projektivitu
# stromu!
#------------------------------------------------------------------------------
sub zjistit_povol_shora_dolu
{
    my $rodic = shift; # odkaz na rozpracovaný strom
    my @povol; # výstupní pole
    # Povolené jsou závislosti uzlů, které ještě ve stromu nejsou, na uzlech,
    # které již ve stromu jsou.
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
# Zjistí, zda určitá závislost je povolená. Pokud dostane odkaz na seznam
# povolených závislostí, pouze projde tento seznam. Jinak si ho nejdřív sama
# zjistí podle globální proměnné @rodic.
#------------------------------------------------------------------------------
sub je_povoleno
{
    my $anot = shift;
    my $r = shift;
    my $z = shift;
    my $povolref = shift;
    my @povol;
    if(!$povolref)
    {
        @povol = zjistit_povol($anot, @rodic);
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
# Načte seznam rematizátorů. Podle nich se dají poznat neprojektivity typu
# rematizátor - předložka - slovo visící na předložce a řídící rematizátor.
#------------------------------------------------------------------------------
sub cist_rematizatory
{
    open(REM, "rematizatory.txt") or die("Nelze otevrit rematizatory: $!\n");
    binmode(REM, ":encoding(iso-8859-2)");
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
# Povolí neprojektivní závislosti rematizátorů na slovech za předložkou nad
# rámec toho, co dovoluje modul povol. Podmínkou je, že ještě nebyla narušena
# situace, která neprojektivity způsobuje, tj. především rematizátor ještě nemá
# rodiče, dále předložka nevisí ani na rematizátoru, ani na slově za ní.
#------------------------------------------------------------------------------
sub povolit_rematizator_za_predlozku
{
    my $anot = shift;
    my $rodic = shift; # rozpracovaný strom
    my @povol = povolit_infinitivy($anot, $rodic);
    for(my $i = 0; $i<$#{$anot}; $i++)
    {
        # Kvůli obavě z cyklů raději požadovat, aby uzel za předložkou byl
        # připojen nanejvýš na předložku a předložka aby ještě rodiče neměla vůbec.
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
# už na něm visí (přesně řečeno, povolíme, aby na infinitivu viselo navíc vše,
# co může viset na jeho rodiči.
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
            # Povolit všem uzlům, které mohou zleva viset na uzlu nalevo od
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
# Povolí neprojektivní závislosti přes -li.
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
            # Povolit všem uzlům, které mohou zprava viset na li, aby visely i
            # na slově před pomlčkou.
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
    }
    return @povol;
}



1;
