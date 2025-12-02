package com.example.chovoshayom;

public class TasksSetup {
    public static void setupTasks(){
        ParentTask tanach = new ParentTask("Tanach", "Perek");
        ParentTask mishnayos = new ParentTask("Mishnayos", "Perek");
        ParentTask shas = new ParentTask("Shas", "Daf");
        //        This differs from the commonly accepted number of 2711. That is because of two factors:
//          1. We did not include Shekalim, as it is Yerushalmi.
//          2. We counted an amud at the end of a mesechta as half a daf, not a full daf.
        ParentTask yerushalmi = new ParentTask("Yerushalmi", "Halacha");
        ParentTask rambam = new ParentTask("Rambam", "Perek");
        ParentTask tur = new ParentTask("Tur", "Siman");
        ParentTask shulchanAruch = new ParentTask("Shulchan Aruch", "Siman");
        ParentTask mishnaBerura = new ParentTask("Mishna Berura", "Siman");

        ChildTask torah = new ChildTask("Torah", tanach);
        ChildTask neviim = new ChildTask("Neviim", tanach);
        ChildTask kesuvim = new ChildTask("Kesuvim", tanach);
        ChildTask[] tanachChildren = {torah, neviim, kesuvim};

        ChildTask zeraim = new ChildTask("Zeraim", mishnayos);
        ChildTask moed = new ChildTask("Moed", mishnayos);
        ChildTask nashim = new ChildTask("Nashim", mishnayos);
        ChildTask nezikin = new ChildTask("Nezikin", mishnayos);
        ChildTask kodshim = new ChildTask("Kodshim", mishnayos);
        ChildTask taharos = new ChildTask("Taharos", mishnayos);
        ChildTask[] mishnayosChildren = {zeraim, moed, nashim, nezikin, kodshim, taharos};

        ChildTask zeraimShas = new ChildTask("Zeraim (Shas)", shas);
        ChildTask moedShas = new ChildTask("Moed (Shas)", shas);
        ChildTask nashimShas = new ChildTask("Nashim (Shas)", shas);
        ChildTask nezikinShas = new ChildTask("Nezikin (Shas)", shas);
        ChildTask kodshimShas = new ChildTask("Kodshim (Shas)", shas);
        ChildTask taharosShas = new ChildTask("Taharos (Shas)", shas);
        ChildTask[] shasChildren = {zeraimShas, moedShas, nashimShas, nezikinShas, kodshimShas, taharosShas};

        ChildTask zeraimYerushalmi = new ChildTask("Zeraim (Yerushalmi)", yerushalmi);
        ChildTask moedYerushalmi = new ChildTask("Moed (Yerushalmi)", yerushalmi);
        ChildTask nashimYerushalmi = new ChildTask("Nashim (Yerushalmi)", yerushalmi);
        ChildTask nezikinYerushalmi = new ChildTask("Nezikin (Yerushalmi)", yerushalmi);
        ChildTask taharosYerushalmi = new ChildTask("Taharos (Yerushalmi)", yerushalmi);
        ChildTask[] yerushalmiChildren = {zeraimYerushalmi, moedYerushalmi, nashimYerushalmi, nezikinYerushalmi, taharosYerushalmi};

        GrandchildTask bereishis = new GrandchildTask("Bereishis", 50, torah);
        GrandchildTask shemos = new GrandchildTask("Shemos", 40, torah);
        GrandchildTask vayikrah = new GrandchildTask("Vayikrah", 27, torah);
        GrandchildTask bamidbar = new GrandchildTask("Bamidbar", 36, torah);
        GrandchildTask devarim = new GrandchildTask("Devarim", 34, torah);
        GrandchildTask[] torahChildren = {bereishis, shemos, vayikrah, bamidbar, devarim};

        GrandchildTask yehoshua = new GrandchildTask("Yehoshua", 24, neviim);
        GrandchildTask shoftim = new GrandchildTask("Shoftim", 21, neviim);
        GrandchildTask shmuelA = new GrandchildTask("Shmuel Alef", 31, neviim);
        GrandchildTask shmuelB = new GrandchildTask("Shmuel Beis", 24, neviim);
        GrandchildTask melachimA = new GrandchildTask("Melachim Alef", 22, neviim);
        GrandchildTask melachimB = new GrandchildTask("Melachim Beis", 25, neviim);
        GrandchildTask yeshaya = new GrandchildTask("Yeshaya", 66, neviim);
        GrandchildTask yirmiya = new GrandchildTask("Yirmiya", 52, neviim);
        GrandchildTask yechezkel = new GrandchildTask("Yechezkel", 48, neviim);
        GrandchildTask treiAsar = new GrandchildTask("Trei Asar", 67, neviim);
        GrandchildTask[] neviimChildren = {yehoshua, shoftim, shmuelA, shmuelB, melachimA, melachimB, yeshaya, yirmiya, yechezkel, treiAsar};

        GrandchildTask divreiHayamimA = new GrandchildTask("Divrei Hayamim Alef", 29, kesuvim);
        GrandchildTask divreiHayamimB = new GrandchildTask("Divrei Hayamim Beis", 36, kesuvim);
        GrandchildTask tehillim = new GrandchildTask("Tehillim", 150, kesuvim);
        GrandchildTask iyov = new GrandchildTask("Iyov", 42, kesuvim);
        GrandchildTask mishlei = new GrandchildTask("Mishlei",  31, kesuvim);
        GrandchildTask rus = new GrandchildTask("Rus",  4, kesuvim);
        GrandchildTask shirHashirim = new GrandchildTask("Shie HaShirim",  8, kesuvim);
        GrandchildTask koheles = new GrandchildTask("Koheles", 12, kesuvim);
        GrandchildTask eichah = new GrandchildTask("Eichah", 5, kesuvim);
        GrandchildTask esther = new GrandchildTask("Esther", 10, kesuvim);
        GrandchildTask daniel = new GrandchildTask("Daniel", 12, kesuvim);
        GrandchildTask ezra = new GrandchildTask("Ezra", 10, kesuvim);
        GrandchildTask nechemia = new GrandchildTask("Nechemia",  13, kesuvim);
        GrandchildTask[] kesuvimChildren = {divreiHayamimA, divreiHayamimB, tehillim, iyov, mishlei, rus, shirHashirim, koheles, eichah, esther, daniel, ezra, nechemia};

        GrandchildTask brachos = new GrandchildTask("Brachos", 9, zeraim);
        GrandchildTask peah = new GrandchildTask("Peah", 8, zeraim);
        GrandchildTask demai = new GrandchildTask("Demai",  7, zeraim);
        GrandchildTask kelayim = new GrandchildTask("Kelayim", 9, zeraim);
        GrandchildTask shviis = new GrandchildTask("Shviis", 10, zeraim);
        GrandchildTask terumos = new GrandchildTask("Terumos", 11, zeraim);
        GrandchildTask maasros = new GrandchildTask("Maasros",5, zeraim);
        GrandchildTask maaserSheni = new GrandchildTask("Maaser Sheni",  5, zeraim);
        GrandchildTask challah = new GrandchildTask("Challah",  4, zeraim);
        GrandchildTask orlah = new GrandchildTask("Orlah",3, zeraim);
        GrandchildTask bikkurim = new GrandchildTask("Bikkurim", 4, zeraim);


        GrandchildTask shabbos = new GrandchildTask("Shabbos", 24, moed);
        GrandchildTask eiruvin = new GrandchildTask("Eiruvin", 10, moed);
        GrandchildTask pesachim = new GrandchildTask("Pesachim",  10, moed);
        GrandchildTask shekalim = new GrandchildTask("Shekalim", 8, moed);
        GrandchildTask yoma = new GrandchildTask("Yoma", 8, moed);
        GrandchildTask sukkah = new GrandchildTask("Sukkah",  5, moed);
        GrandchildTask beitza = new GrandchildTask("Beitza",  5, moed);
        GrandchildTask roshHashana = new GrandchildTask("Roah Hashana", 4, moed);
        GrandchildTask taanis = new GrandchildTask("Taanis", 4, moed);
        GrandchildTask megilla = new GrandchildTask("Megilla", 4, moed);
        GrandchildTask moedKatan = new GrandchildTask("Moed Katan", 3, moed);
        GrandchildTask chagiga = new GrandchildTask("Chagiga", 3, moed);

        GrandchildTask yevamos = new GrandchildTask("Yevamos", 16, nashim);
        GrandchildTask kesuvos = new GrandchildTask("Kesuvos", 13, nashim);
        GrandchildTask nedarim = new GrandchildTask("Nedarim",  11, nashim);
        GrandchildTask nazir = new GrandchildTask("Nazir", 9, nashim);
        GrandchildTask sottah = new GrandchildTask("Sottah",  9, nashim);
        GrandchildTask gittin = new GrandchildTask("Gittin", 9, nashim);
        GrandchildTask kiddushin = new GrandchildTask("Kiddushin", 4, nashim);

        GrandchildTask bavaKama = new GrandchildTask("Bava Kama", 10, nezikin);
        GrandchildTask bavaMetzia = new GrandchildTask("Bava Metzia", 10, nezikin);
        GrandchildTask bavaBasra = new GrandchildTask("Bava Basra", 10, nezikin);
        GrandchildTask sanhedrin = new GrandchildTask("Sanhedrin", 11, nezikin);
        GrandchildTask makkos = new GrandchildTask("Makkos",  13, nezikin);
        GrandchildTask shevuos = new GrandchildTask("Shevuos",  8, nezikin);
        GrandchildTask eduyos = new GrandchildTask("Eduyos", 8, nezikin);
        GrandchildTask avodaZarah = new GrandchildTask("Avodah Zarah", 5, nezikin);
        GrandchildTask avos = new GrandchildTask("Avos", 6, nezikin);
        GrandchildTask horayos = new GrandchildTask("Horayos", 3, nezikin);

        GrandchildTask zevachim = new GrandchildTask("Zevachim", 14, kodshim);
        GrandchildTask minachos = new GrandchildTask("Minachos", 13, kodshim);
        GrandchildTask chullin = new GrandchildTask("Chullin", 12, kodshim);
        GrandchildTask bechoros = new GrandchildTask("Bechoros",  9, kodshim);
        GrandchildTask erchin = new GrandchildTask("Erchin", 9, kodshim);
        GrandchildTask temurah = new GrandchildTask("Temurah",  7, kodshim);
        GrandchildTask kerisos = new GrandchildTask("Kerisos", 6, kodshim);
        GrandchildTask meilah = new GrandchildTask("Meilah", 6, kodshim);
        GrandchildTask tamid = new GrandchildTask("Tamid", 7, kodshim);
        GrandchildTask middos = new GrandchildTask("Middos", 5, kodshim);
        GrandchildTask kinnim = new GrandchildTask("Kinnim", 3, kodshim);
        GrandchildTask keilim = new GrandchildTask("Keilim", 30, taharos);
        GrandchildTask oholos = new GrandchildTask("Oholos",18, taharos);
        GrandchildTask negaim = new GrandchildTask("Negaim", 14, taharos);
        GrandchildTask parah = new GrandchildTask("Parah", 12, taharos);
        GrandchildTask taharosMesechta = new GrandchildTask("Taharos (Mesechta)", 10, taharos);
        GrandchildTask mikvaos = new GrandchildTask("Mikvaos", 10, taharos);
        GrandchildTask niddah = new GrandchildTask("Niddah", 10, taharos);
        GrandchildTask machshirin = new GrandchildTask("Machshirin", 6, taharos);
        GrandchildTask zavim = new GrandchildTask("Zavim", 5, taharos);
        GrandchildTask tevulYom = new GrandchildTask("Tevul Yom", 4, taharos);
        GrandchildTask yadayim = new GrandchildTask("Yadayim", 4, taharos);
        GrandchildTask uktzin = new GrandchildTask("Uktzin", 3, taharos);

        GrandchildTask berachosShas = new GrandchildTask("Berachos (Shas)", 62.5, zeraimShas);

        GrandchildTask shabbosShas = new GrandchildTask("Shabbos (Shas)", 156, moedShas);
        GrandchildTask eruvinShas = new GrandchildTask("Eruvin (Shas)", 103.5, moedShas);
        GrandchildTask pesachimShas = new GrandchildTask("Pesachim (Shas)", 120, moedShas);
        GrandchildTask roshHashanaShas = new GrandchildTask("Roah Hashana (Shas)", 33.5, moedShas);
        GrandchildTask YomaShas = new GrandchildTask("Yoma (Shas)", 86.5, moedShas);
        GrandchildTask sukkahShas = new GrandchildTask("Sukkah (Shas)", 55, moedShas);
        GrandchildTask beitzaShas = new GrandchildTask("Beitza (Shas)", 39, moedShas);
        GrandchildTask taanisShas = new GrandchildTask("Taanis (Shas)", 29.5, moedShas);
        GrandchildTask megillaShas = new GrandchildTask("Megilla (Shas)", 30.5, moedShas);
        GrandchildTask moedKatanShas = new GrandchildTask("Moed Katan (Shas)", 27.5, moedShas);
        GrandchildTask chagigaShas = new GrandchildTask("Chagiga (Shas)", 25.5, moedShas);

        GrandchildTask yevamosShas = new GrandchildTask("Yevamos (Shas)", 121, nashimShas);
        GrandchildTask kesuvosShas = new GrandchildTask("Kesuvos (Shas)", 111, nashimShas);
        GrandchildTask nedarimShas = new GrandchildTask("Nedarim (Shas)", 90, nashimShas);
        GrandchildTask nazirShas = new GrandchildTask("Nazir (Shas)", 65, nashimShas);
        GrandchildTask sotahShas = new GrandchildTask("Sotah (Shas)", 48, nashimShas);
        GrandchildTask gittinShas = new GrandchildTask("Gittin (Shas)", 89, nashimShas);
        GrandchildTask kiddushinShas = new GrandchildTask("Kiddushin (Shas)", 81, nashimShas);

        GrandchildTask bavaKamaShas = new GrandchildTask ("Bava Kama (Shas)", 118, nezikinShas);
        GrandchildTask bavaMetziaShas = new GrandchildTask ("Bava Metzia (Shas)", 117.5, nezikinShas);
        GrandchildTask bavaBasraShas = new GrandchildTask ("Bava Basra (Shas)", 175, nezikinShas);
        GrandchildTask sanhedrinShas = new GrandchildTask ("Sanhedrin (Shas)", 112, nezikinShas);
        GrandchildTask makkosShas = new GrandchildTask ("Makkos (Shas)", 23, nezikinShas);
        GrandchildTask shevuosShas = new GrandchildTask ("Shevuos (Shas)", 48, nezikinShas);
        GrandchildTask avodahZarahShas = new GrandchildTask ("Avodah Zarah (Shas)", 75, nezikinShas);
        GrandchildTask horayosShas = new GrandchildTask ("Horayos (Shas)", 12.5, nezikinShas);

        GrandchildTask zevachimShas = new GrandchildTask("Zevachim (Shas)", 119, kodshimShas);
        GrandchildTask menachosShas = new GrandchildTask("Menachos (Shas)", 108.5, kodshimShas);
        GrandchildTask chullinShas = new GrandchildTask("Chullin (Shas)", 140.5, kodshimShas);
        GrandchildTask bechorosShas = new GrandchildTask("Bechoros (Shas)", 59.5, kodshimShas);
        GrandchildTask erchinShas = new GrandchildTask("Erchin (Shas)", 32.5, kodshimShas);
        GrandchildTask temurahShas = new GrandchildTask("Temurah (Shas)", 32.5, kodshimShas);
        GrandchildTask kerisosShas = new GrandchildTask("Kerisos (Shas)", 27, kodshimShas);
        GrandchildTask meilahShas = new GrandchildTask("Meilah (Shas)", 20.5, kodshimShas);
        GrandchildTask tamidShas = new GrandchildTask("Tamid (Shas)", 8.5, kodshimShas);

        GrandchildTask niddahShas = new GrandchildTask("Niddah (Shas)", 71.5, taharosShas);

        GrandchildTask berachosYerushalmi = new GrandchildTask("Berachos (Yerushalmi)", 58, zeraimYerushalmi);
        GrandchildTask peahYerushalmi = new GrandchildTask("Peah (Yerushalmi)", 55, zeraimYerushalmi);
        GrandchildTask demaiYerushalmi = new GrandchildTask("Demai (Yerushalmi)", 44, zeraimYerushalmi);
        GrandchildTask kilayimYerushalmi = new GrandchildTask("Kilayim (Yerushalmi)", 56, zeraimYerushalmi);
        GrandchildTask shviisYerushalmi = new GrandchildTask("Shviis (Yerushalmi)", 56, zeraimYerushalmi);
        GrandchildTask terumosYerushalmi = new GrandchildTask("Terumos (Yerushalmi)", 48, zeraimYerushalmi);
        GrandchildTask maasrosYerushalmi = new GrandchildTask("Maasros (Yerushalmi)", 20, zeraimYerushalmi);
        GrandchildTask maaserSheniYerushalmi = new GrandchildTask("Maaser Sheni (Yerushalmi)", 24, zeraimYerushalmi);
        GrandchildTask challahYerushalmi = new GrandchildTask("Challah (Yerushalmi)", 19, zeraimYerushalmi);
        GrandchildTask orlahYerushalmi = new GrandchildTask("Orlah (Yerushalmi)", 21, zeraimYerushalmi);
        GrandchildTask bikkurimYerushalmi = new GrandchildTask("Bikkurim (Yerushalmi)", 21, zeraimYerushalmi);

        GrandchildTask shabbosYerushalmi = new GrandchildTask("Shabbos (Yerushalmi)", 141, moedYerushalmi);
        GrandchildTask eruvinYerushalmi = new GrandchildTask("Eruvin (Yerushalmi)", 94, moedYerushalmi);
        GrandchildTask pesachimYerushalmi = new GrandchildTask("Pesachim (Yerushalmi)", 86, moedYerushalmi);
        GrandchildTask yomaYerushalmi = new GrandchildTask("Yoma (Yerushalmi)", 51, moedYerushalmi);
        GrandchildTask shekalimYerushalmi = new GrandchildTask("Shekalim (Yerushalmi)", 32, moedYerushalmi);
        GrandchildTask sukkahYerushalmi = new GrandchildTask("Sukkah (Yerushalmi)", 49, moedYerushalmi);
        GrandchildTask roshHashanaYerushalmi = new GrandchildTask("Rosh Hashana (Yerushalmi)", 36, moedYerushalmi);
        GrandchildTask beitzaYerushalmi = new GrandchildTask("Beitza (Yerushalmi)", 46, moedYerushalmi);
        GrandchildTask taanisYerushalmi = new GrandchildTask("Taanis (Yerushalmi)", 40, moedYerushalmi);
        GrandchildTask megillahYerushalmi = new GrandchildTask("Megillah (Yerushalmi)", 38, moedYerushalmi);
        GrandchildTask chagigahYerushalmi = new GrandchildTask("Chagigah (Yerushalmi)", 23, moedYerushalmi);
        GrandchildTask moedKatanYerushalmi = new GrandchildTask("Moed Katan (Yerushalmi)", 24, moedYerushalmi);

        GrandchildTask yevamosYerushalmi = new GrandchildTask("Yevamos (Yerushalmi)", 143, nashimYerushalmi);
        GrandchildTask sotahYerushalmi = new GrandchildTask("Sotah (Yerushalmi)", 73, nashimYerushalmi);
        GrandchildTask kesuvosYerushalmi = new GrandchildTask("Kesuvos (Yerushalmi)", 121, nashimYerushalmi);
        GrandchildTask nedarimYerushalmi = new GrandchildTask("Nedarim (Yerushalmi)", 94, nashimYerushalmi);
        GrandchildTask nazirYerushalmi = new GrandchildTask("Nazir (Yerushalmi)", 55, nashimYerushalmi);
        GrandchildTask gittinYerushalmi = new GrandchildTask("Gittin (Yerushalmi)", 75, nashimYerushalmi);
        GrandchildTask kidushinYerushalmi = new GrandchildTask("Kidushin (Yerushalmi)", 43, nashimYerushalmi);

        GrandchildTask bavaKamaYerushalmi = new GrandchildTask ("Bava Kama (Yerushalmi)", 85, nezikin);
        GrandchildTask bavaMetziaYerushalmi = new GrandchildTask ("Bava Metzia (Yerushalmi)", 84, nezikin);
        GrandchildTask bavaBasraYerushalmi = new GrandchildTask ("Bava Basra (Yerushalmi)", 76, nezikin);
        GrandchildTask sanhedrinYerushalmi = new GrandchildTask ("Sanhedrin (Yerushalmi)", 89, nezikin);
        GrandchildTask shevuosYerushalmi = new GrandchildTask ("Shevuos (Yerushalmi)", 58, nezikin);
        GrandchildTask avodahZarahYerushalmi = new GrandchildTask ("Avodah Zarah (Yerushalmi)", 60, nezikin);
        GrandchildTask makkosYerushalmi = new GrandchildTask ("Makkos (Yerushalmi)", 28, nezikin);
        GrandchildTask horayosYerushalmi = new GrandchildTask ("Horayos (Yerushalmi)", 20, nezikin);

        GrandchildTask niddahYerushalmi = new GrandchildTask("Niddah (Yerushalmi)", 25, taharosYerushalmi);


        GrandchildTask maddah = new GrandchildTask("Maddah", 46, rambam);
        GrandchildTask ahava = new GrandchildTask("Ahava", 51, rambam);
        GrandchildTask zemanim = new GrandchildTask("Zemanim", 98, rambam);
        GrandchildTask nashimRambam = new GrandchildTask("Nashim", 53, rambam);
        GrandchildTask kedusha = new GrandchildTask("Kedusha", 53, rambam);
        GrandchildTask haflaah = new GrandchildTask("Haflaah", 43, rambam);
        GrandchildTask zeraimRambam = new GrandchildTask("Zeraim (Rambam)", 85, rambam);
        GrandchildTask avodah = new GrandchildTask("Avodah", 95, rambam);
        GrandchildTask korbanos = new GrandchildTask("Korbanos", 45, rambam);
        GrandchildTask tahara = new GrandchildTask("Tahara", 144, rambam);
        GrandchildTask nezikinRambam = new GrandchildTask("Nezikin (Rambam)", 62, rambam);
        GrandchildTask kinyan = new GrandchildTask("Kinyan", 75, rambam);
        GrandchildTask mishpatim = new GrandchildTask("Mishpatim", 75, rambam);
        GrandchildTask shoftimRambam = new GrandchildTask("Shoftim", 81, rambam);
        GrandchildTask orachChaim = new GrandchildTask("Orech Chaim (Tur)", 697, tur);
        GrandchildTask yorehDeah = new GrandchildTask("Yoreh Deah (Tur)", 403, tur);
        GrandchildTask choshenMishpat = new GrandchildTask("Choshen Mishpat (Tur)", 427, tur);
        GrandchildTask evenHaezer = new GrandchildTask("Even Haezer (Tur)", 178, tur);
        GrandchildTask orachChaimSA = new GrandchildTask("Orech Chaim (Shulchan Aruch)", 697, shulchanAruch);
        GrandchildTask yorehDeahSA = new GrandchildTask("Yoreh Deah (Shulchan Aruch)", 403, shulchanAruch);
        GrandchildTask choshenMishpatSA = new GrandchildTask("Choshen Mishpat (Shulchan Aruch)", 427, shulchanAruch);
        GrandchildTask evenHaezerSA = new GrandchildTask("Even Haezer (Shulchan Aruch)", 178, shulchanAruch);
        GrandchildTask chelek1 = new GrandchildTask("Cheleck Alef" , 127, mishnaBerura);
        GrandchildTask chelek2 = new GrandchildTask("Cheleck Beis" , 114, mishnaBerura);
        GrandchildTask chelek3 = new GrandchildTask("Cheleck Gimmel" , 103, mishnaBerura);
        GrandchildTask chelek4 = new GrandchildTask("Cheleck Daled" , 84, mishnaBerura);
        GrandchildTask chelek5 = new GrandchildTask("Cheleck Hei" , 99, mishnaBerura);
        GrandchildTask chelek6 = new GrandchildTask("Cheleck Vuv" , 168, mishnaBerura);

    }
}
