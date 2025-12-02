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

        ChildTask zeraim = new ChildTask("Zeraim", mishnayos);
        ChildTask moed = new ChildTask("Moed", mishnayos);
        ChildTask nashim = new ChildTask("Nashim", mishnayos);
        ChildTask nezikin = new ChildTask("Nezikin", mishnayos);
        ChildTask kodshim = new ChildTask("Kodshim", mishnayos);
        ChildTask taharos = new ChildTask("Taharos", mishnayos);

        ChildTask zeraimShas = new ChildTask("Zeraim (Shas)", shas);
        ChildTask moedShas = new ChildTask("Moed (Shas)", shas);
        ChildTask nashimShas = new ChildTask("Nashim (Shas)", shas);
        ChildTask nezikinShas = new ChildTask("Nezikin (Shas)", shas);
        ChildTask kodshimShas = new ChildTask("Kodshim (Shas)", shas);
        ChildTask taharosShas = new ChildTask("Taharos (Shas)", shas);

        ChildTask zeraimYerushalmi = new ChildTask("Zeraim (Yerushalmi)", yerushalmi);
        ChildTask moedYerushalmi = new ChildTask("Moed (Yerushalmi)", yerushalmi);
        ChildTask nashimYerushalmi = new ChildTask("Nashim (Yerushalmi)", yerushalmi);
        ChildTask nezikinYerushalmi = new ChildTask("Nezikin (Yerushalmi)", yerushalmi);
        ChildTask taharosYerushalmi = new ChildTask("Taharos (Yerushalmi)", yerushalmi);

        GrandchildTask bereishis = new GrandchildTask("Bereishis", 50, torah);
        GrandchildTask shemos = new GrandchildTask("Shemos", 40, torah);
        GrandchildTask vayikrah = new GrandchildTask("Vayikrah", 27, torah);
        GrandchildTask bamidbar = new GrandchildTask("Bamidbar", 36, torah);
        GrandchildTask devarim = new GrandchildTask("Devarim", 34, torah);

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

        GrandchildTask shabbos = new GrandchildTask("Shabbos", "Perek", 24, moed);
        GrandchildTask eiruvin = new GrandchildTask("Eiruvin", "Perek", 10, moed);
        GrandchildTask pesachim = new GrandchildTask("Pesachim", "Perek", 10, moed);
        GrandchildTask shekalim = new GrandchildTask("Shekalim", "Perek", 8, moed);
        GrandchildTask yoma = new GrandchildTask("Yoma", "Perek", 8, moed);
        GrandchildTask sukkah = new GrandchildTask("Sukkah", "Perek", 5, moed);
        GrandchildTask beitza = new GrandchildTask("Beitza", "Perek", 5, moed);
        GrandchildTask roshHashana = new GrandchildTask("Roah Hashana", "Perek", 4, moed);
        GrandchildTask taanis = new GrandchildTask("Taanis", "Perek", 4, moed);
        GrandchildTask megilla = new GrandchildTask("Megilla", "Perek", 4, moed);
        GrandchildTask moedKatan = new GrandchildTask("Moed Katan", "Perek", 3, moed);
        GrandchildTask chagiga = new GrandchildTask("Chagiga", "Perek", 3, moed);

        GrandchildTask yevamos = new Task("Yevamos", "Perek", 16, nashim);
        GrandchildTask kesuvos = new Task("Kesuvos", "Perek", 13, nashim);
        GrandchildTask nedarim = new Task("Nedarim", "Perek", 11, nashim);
        GrandchildTask nazir = new Task("Nazir", "Perek", 9, nashim);
        GrandchildTask sottah = new Task("Sottah", "Perek", 9, nashim);
        GrandchildTask gittin = new Task("Gittin", "Perek", 9, nashim);
        GrandchildTask kiddushin = new Task("Kiddushin", "Perek", 4, nashim);
        GrandchildTask bavaKama = new Task("Bava Kama", "Perek", 10, nezikin);
        GrandchildTask bavaMetzia = new Task("Bava Metzia", "Perek", 10, nezikin);
        GrandchildTask bavaBasra = new Task("Bava Basra", "Perek", 10, nezikin);
        GrandchildTask sanhedrin = new Task("Sanhedrin", "Perek", 11, nezikin);
        GrandchildTask makkos = new Task("Makkos", "Perek", 13, nezikin);
        GrandchildTask shevuos = new Task("Shevuos", "Perek", 8, nezikin);
        GrandchildTask eduyos = new Task("Eduyos", "Perek", 8, nezikin);
        GrandchildTask avodaZarah = new Task("Avodah Zarah", "Perek", 5, nezikin);
        GrandchildTask avos = new Task("Avos", "Perek", 6, nezikin);
        GrandchildTask horayos = new Task("Horayos", "Perek", 3, nezikin);
        GrandchildTask zevachim = new Task("Zevachim", "Perek", 14, kodshim);
        GrandchildTask minachos = new Task("Minachos", "Perek", 13, kodshim);
        GrandchildTask chullin = new Task("Chullin", "Perek", 12, kodshim);
        GrandchildTask bechoros = new Task("Bechoros", "Perek", 9, kodshim);
        GrandchildTask erchin = new Task("Erchin", "Perek", 9, kodshim);
        GrandchildTask temurah = new Task("Temurah", "Perek", 7, kodshim);
        GrandchildTask kerisos = new Task("Kerisos", "Perek", 6, kodshim);
        GrandchildTask meilah = new Task("Meilah", "Perek", 6, kodshim);
        GrandchildTask tamid = new Task("Tamid", "Perek", 7, kodshim);
        GrandchildTask middos = new Task("Middos", "Perek", 5, kodshim);
        GrandchildTask kinnim = new Task("Kinnim", "Perek", 3, kodshim);
        GrandchildTask keilim = new Task("Keilim", "Perek", 30, taharos);
        GrandchildTask oholos = new Task("Oholos", "Perek", 18, taharos);
        GrandchildTask negaim = new Task("Negaim", "Perek", 14, taharos);
        GrandchildTask parah = new Task("Parah", "Perek", 12, taharos);
        GrandchildTask taharosMesechta = new Task("Taharos (Mesechta)", "Perek", 10, taharos);
        GrandchildTask mikvaos = new Task("Mikvaos", "Perek", 10, taharos);
        GrandchildTask niddah = new Task("Niddah", "Perek", 10, taharos);
        GrandchildTask machshirin = new Task("Machshirin", "Perek", 6, taharos);
        GrandchildTask zavim = new Task("Zavim", "Perek", 5, taharos);
        GrandchildTask tevulYom = new Task("Tevul Yom", "Perek", 4, taharos);
        GrandchildTask yadayim = new Task("Yadayim", "Perek", 4, taharos);
        GrandchildTask uktzin = new Task("Uktzin", "Perek", 3, taharos);

        GrandchildTask berachosShas = new Task("Berachos (Shas)", "Daf", 62.5, zeraimShas);
        GrandchildTask shabbosShas = new task("Shabbos (Shas)", "Daf", 156, moedShas);
        GrandchildTask eruvinShas = new task("Eruvin (Shas)", "Daf", 103.5, moedShas);
        GrandchildTask pesachimShas = new task("Pesachim (Shas)", "Daf", 120, moedShas);
        GrandchildTask roshHashanaShas = new task("Roah Hashana (Shas)", "Daf", 33.5, moedShas);
        GrandchildTask YomaShas = new task("Yoma (Shas)", "Daf", 86.5, moedShas);
        GrandchildTask sukkahShas = new task("Sukkah (Shas)", "Daf", 55, moedShas);
        GrandchildTask beitzaShas = new task("Beitza (Shas)", "Daf", 39, moedShas);
        GrandchildTask taanisShas = new task("Taanis (Shas)", "Daf", 29.5, moedShas);
        GrandchildTask megillaShas = new task("Megilla (Shas)", "Daf", 30.5, moedShas);
        GrandchildTask megillaShas = new task("Megilla (Shas)", "Daf", 30.5, moedShas);
        GrandchildTask moedKatanShas = new task("Moed Katan (Shas)", "Daf", 27.5, moedShas);
        GrandchildTask chagigaShas = new task("Chagiga (Shas)", "Daf", 25.5, moedShas);
        GrandchildTask yevamosShas = new Task("Yevamos (Shas)", "Daf", 121, nashimShas);
        GrandchildTask kesuvosShas = new Task("Kesuvos (Shas)", "Daf", 111, nashimShas);
        GrandchildTask nedarimShas = new Task("Nedarim (Shas)", "Daf", 90, nashimShas);
        GrandchildTask nazirShas = new Task("Nazir (Shas)", "Daf", 65, nashimShas);
        GrandchildTask sotahShas = new Task("Sotah (Shas)", "Daf", 48, nashimShas);
        GrandchildTask gittinShas = new Task("Gittin (Shas)", "Daf", 89, nashimShas);
        GrandchildTask kiddushinShas = new Task("Kiddushin (Shas)", "Daf", 81, nashimShas);
        GrandchildTask bavaKamaShas = new Task ("Bava Kama (Shas)", "Daf", 118, nezikinShas);
        GrandchildTask bavaMetziaShas = new Task ("Bava Metzia (Shas)", "Daf", 117.5, nezikinShas);
        GrandchildTask bavaBasraShas = new Task ("Bava Basra (Shas)", "Daf", 175, nezikinShas);
        GrandchildTask sanhedrinShas = new Task ("Sanhedrin (Shas)", "Daf", 112, nezikinShas);
        GrandchildTask makkosShas = new Task ("Makkos (Shas)", "Daf", 23, nezikinShas);
        GrandchildTask shevuosShas = new Task ("Shevuos (Shas)", "Daf", 48, nezikinShas);
        GrandchildTask avodahZarahShas = new Task ("Avodah Zarah (Shas)", "Daf", 75, nezikinShas);
        GrandchildTask horayosShas = new Task ("Horayos (Shas)", "Daf", 12.5, nezikinShas);
        GrandchildTask zevachimShas = new Task("Zevachim (Shas)", "Daf", 119, kodshimShas);
        GrandchildTask menachosShas = new Task("Menachos (Shas)", "Daf", 108.5, kodshimShas);
        GrandchildTask chullinShas = new Task("Chullin (Shas)", "Daf", 140.5, kodshimShas);
        GrandchildTask bechorosShas = new Task("Bechoros (Shas)", "Daf", 59.5, kodshimShas);
        GrandchildTask erchinShas = new Task("Erchin (Shas)", "Daf", 32.5, kodshimShas);
        GrandchildTask temurahShas = new Task("Temurah (Shas)", "Daf", 32.5, kodshimShas);
        GrandchildTask kerisosShas = new Task("Kerisos (Shas)", "Daf", 27, kodshimShas);
        GrandchildTask meilahShas = new Task("Meilah (Shas)", "Daf", 20.5, kodshimShas);
        GrandchildTask tamidShas = new Task("Tamid (Shas)", "Daf", 8.5, kodshimShas);
        GrandchildTask niddahShas = new Tak("Niddah (Shas)", "Daf", 71.5, taharosShas);
        GrandchildTask berachosYerushalmi = new Task("Berachos (Yerushalmi)", "Halacha", 58, zeraimYerushalmi);
        GrandchildTask peahYerushalmi = new Task("Peah (Yerushalmi)", "Halacha", 55, zeraimYerushalmi);
        GrandchildTask demaiYerushalmi = new Task("Demai (Yerushalmi)", "Halacha", 44, zeraimYerushalmi);
        GrandchildTask kilayimYerushalmi = new Task("Kilayim (Yerushalmi)", "Halacha", 56, zeraimYerushalmi);
        GrandchildTask shviisYerushalmi = new Task("Shviis (Yerushalmi)", "Halacha", 56, zeraimYerushalmi);
        GrandchildTask terumosYerushalmi = new Task("Terumos (Yerushalmi)", "Halacha", 48, zeraimYerushalmi);
        GrandchildTask maasrosYerushalmi = new Task("Maasros (Yerushalmi)", "Halacha", 20, zeraimYerushalmi);
        GrandchildTask maaserSheniYerushalmi = new Task("Maaser Sheni (Yerushalmi)", "Halacha", 24, zeraimYerushalmi);
        GrandchildTask challahYerushalmi = new Task("Challah (Yerushalmi)", "Halacha", 19, zeraimYerushalmi);
        GrandchildTask orlahYerushalmi = new Task("Orlah (Yerushalmi)", "Halacha", 21, zeraimYerushalmi);
        GrandchildTask bikkurimYerushalmi = new Task("Bikkurim (Yerushalmi)", "Halacha", 21, zeraimYerushalmi);
        GrandchildTask shabbosYerushalmi = new Task("Shabbos (Yerushalmi)", "Halacha", 141, moedYerushalmi);
        GrandchildTask eruvinYerushalmi = new Task("Eruvin (Yerushalmi)", "Halacha", 94, moedYerushalmi);
        GrandchildTask pesachimYerushalmi = new Task("Pesachim (Yerushalmi)", "Halacha", 86, moedYerushalmi);
        GrandchildTask yomaYerushalmi = new Task("Yoma (Yerushalmi)", "Halacha", 51, moedYerushalmi);
        GrandchildTask shekalimYerushalmi = new Task("Shekalim (Yerushalmi)", "Halacha", 32, moedYerushalmi);
        GrandchildTask sukkahYerushalmi = new Task("Sukkah (Yerushalmi)", "Halacha", 49, moedYerushalmi);
        GrandchildTask roshHashanaYerushalmi = new Task("Rosh Hashana (Yerushalmi)", "Halacha", 36, moedYerushalmi);
        GrandchildTask beitzaYerushalmi = new Task("Beitza (Yerushalmi)", "Halacha", 46, moedYerushalmi);
        GrandchildTask taanisYerushalmi = new Task("Taanis (Yerushalmi)", "Halacha", 40, moedYerushalmi);
        GrandchildTask megillahYerushalmi = new Task("Megillah (Yerushalmi)", "Halacha", 38, moedYerushalmi);
        GrandchildTask chagigahYerushalmi = new Task("Chagigah (Yerushalmi)", "Halacha", 23, moedYerushalmi);
        GrandchildTask moedKatanYerushalmi = new Task("Moed Katan (Yerushalmi)", "Halacha", 24, moedYerushalmi);
        GrandchildTask yevamosYerushalmi = new Task("Yevamos (Yerushalmi)", "Halacha", 143, nashimYerushalmi);
        GrandchildTask sotahYerushalmi = new Task("Sotah (Yerushalmi)", "Halacha", 73, nashimYerushalmi);
        GrandchildTask kesuvosYerushalmi = new Task("Kesuvos (Yerushalmi)", "Halacha", 121, nashimYerushalmi);
        GrandchildTask nedarimYerushalmi = new Task("Nedarim (Yerushalmi)", "Halacha", 94, nashimYerushalmi);
        GrandchildTask nazirYerushalmi = new Task("Nazir (Yerushalmi)", "Halacha", 55, nashimYerushalmi);
        GrandchildTask gittinYerushalmi = new Task("Gittin (Yerushalmi)", "Halacha", 75, nashimYerushalmi);
        GrandchildTask kidushinYerushalmi = new Task("Kidushin (Yerushalmi)", "Halacha", 43, nashimYerushalmi);
        GrandchildTask bavaKamaYerushalmi = new Task ("Bava Kama (Yerushalmi)", "Halacha", 85, nezikin);
        GrandchildTask bavaMetziaYerushalmi = new Task ("Bava Metzia (Yerushalmi)", "Halacha", 84, nezikin);
        GrandchildTask bavaBasraYerushalmi = new Task ("Bava Basra (Yerushalmi)", "Halacha", 76, nezikin);
        GrandchildTask sanhedrinYerushalmi = new Task ("Sanhedrin (Yerushalmi)", "Halacha", 89, nezikin);
        GrandchildTask shevuosYerushalmi = new Task ("Shevuos (Yerushalmi)", "Halacha", 58, nezikin);
        GrandchildTask avodahZarahYerushalmi = new Task ("Avodah Zarah (Yerushalmi)", "Halacha", 60, nezikin);
        GrandchildTask makkosYerushalmi = new Task ("Makkos (Yerushalmi)", "Halacha", 28, nezikin);
        GrandchildTask horayosYerushalmi = new Task ("Horayos (Yerushalmi)", "Halacha", 20, nezikin);
        GrandchildTask niddahYerushalmi = new Task("Niddah (Yerushalmi)", "Halacha", 25, taharosYerushalmi);


    }
}
