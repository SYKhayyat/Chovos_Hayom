package com.example.chovoshayom;

import android.util.Log;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.Set;

public class TasksSetup {
    public static ParentTask tanach = new ParentTask("Tanach", "Perek");
    public static ParentTask mishnayos = new ParentTask("Mishnayos", "Perek");
    public static ParentTask shas = new ParentTask("Shas", "Daf");
    //        This differs from the commonly accepted number of 2711. That is because of two factors:
//          1. We did not include Shekalim, as it is Yerushalmi.
//          2. We counted an amud at the end of a mesechta as half a daf, not a full daf.
    public static ParentTask yerushalmi = new ParentTask("Yerushalmi", "Halacha");
    public static ParentTask rambam = new ParentTask("Rambam", "Perek");
    public static ParentTask tur = new ParentTask("Tur", "Siman");
    public static ParentTask shulchanAruch = new ParentTask("Shulchan Aruch", "Siman");
    public static ParentTask mishnaBerura = new ParentTask("Mishna Berura", "Siman");

    public static ChildTask torah = new ChildTask("Torah", tanach);
    public static ChildTask neviim = new ChildTask("Neviim", tanach);
    public static ChildTask kesuvim = new ChildTask("Kesuvim", tanach);
    public static ChildTask[] tanachChildren = {torah, neviim, kesuvim};

    public static ChildTask zeraim = new ChildTask("Zeraim", mishnayos);
    public static ChildTask moed = new ChildTask("Moed", mishnayos);
    public static ChildTask nashim = new ChildTask("Nashim", mishnayos);
    public static ChildTask nezikin = new ChildTask("Nezikin", mishnayos);
    public static ChildTask kodshim = new ChildTask("Kodshim", mishnayos);
    public static ChildTask taharos = new ChildTask("Taharos", mishnayos);
    public static ChildTask[] mishnayosChildren = {zeraim, moed, nashim, nezikin, kodshim, taharos};

    public static ChildTask zeraimShas = new ChildTask("Zeraim (Shas)", shas);
    public static ChildTask moedShas = new ChildTask("Moed (Shas)", shas);
    public static ChildTask nashimShas = new ChildTask("Nashim (Shas)", shas);
    public static ChildTask nezikinShas = new ChildTask("Nezikin (Shas)", shas);
    public static ChildTask kodshimShas = new ChildTask("Kodshim (Shas)", shas);
    public static ChildTask taharosShas = new ChildTask("Taharos (Shas)", shas);
    public static ChildTask[] shasChildren = {zeraimShas, moedShas, nashimShas, nezikinShas, kodshimShas, taharosShas};

    public static ChildTask zeraimYerushalmi = new ChildTask("Zeraim (Yerushalmi)", yerushalmi);
    public static ChildTask moedYerushalmi = new ChildTask("Moed (Yerushalmi)", yerushalmi);
    public static ChildTask nashimYerushalmi = new ChildTask("Nashim (Yerushalmi)", yerushalmi);
    public static ChildTask nezikinYerushalmi = new ChildTask("Nezikin (Yerushalmi)", yerushalmi);
    public static ChildTask taharosYerushalmi = new ChildTask("Taharos (Yerushalmi)", yerushalmi);
    public static ChildTask[] yerushalmiChildren = {zeraimYerushalmi, moedYerushalmi, nashimYerushalmi, nezikinYerushalmi, taharosYerushalmi};

    public static GrandchildTask bereishis = new GrandchildTask("Bereishis", 50, torah);
    public static GrandchildTask shemos = new GrandchildTask("Shemos", 40, torah);
    public static GrandchildTask vayikrah = new GrandchildTask("Vayikrah", 27, torah);
    public static GrandchildTask bamidbar = new GrandchildTask("Bamidbar", 36, torah);
    public static GrandchildTask devarim = new GrandchildTask("Devarim", 34, torah);
    public static GrandchildTask[] torahChildren = {bereishis, shemos, vayikrah, bamidbar, devarim};

    public static GrandchildTask yehoshua = new GrandchildTask("Yehoshua", 24, neviim);
    public static GrandchildTask shoftim = new GrandchildTask("Shoftim", 21, neviim);
    public static GrandchildTask shmuelA = new GrandchildTask("Shmuel Alef", 31, neviim);
    public static GrandchildTask shmuelB = new GrandchildTask("Shmuel Beis", 24, neviim);
    public static GrandchildTask melachimA = new GrandchildTask("Melachim Alef", 22, neviim);
    public static GrandchildTask melachimB = new GrandchildTask("Melachim Beis", 25, neviim);
    public static GrandchildTask yeshaya = new GrandchildTask("Yeshaya", 66, neviim);
    public static GrandchildTask yirmiya = new GrandchildTask("Yirmiya", 52, neviim);
    public static GrandchildTask yechezkel = new GrandchildTask("Yechezkel", 48, neviim);
    public static GrandchildTask treiAsar = new GrandchildTask("Trei Asar", 67, neviim);
    public static GrandchildTask[] neviimChildren = {yehoshua, shoftim, shmuelA, shmuelB, melachimA, melachimB, yeshaya, yirmiya, yechezkel, treiAsar};

    public static GrandchildTask divreiHayamimA = new GrandchildTask("Divrei Hayamim Alef", 29, kesuvim);
    public static GrandchildTask divreiHayamimB = new GrandchildTask("Divrei Hayamim Beis", 36, kesuvim);
    public static GrandchildTask tehillim = new GrandchildTask("Tehillim", 150, kesuvim);
    public static GrandchildTask iyov = new GrandchildTask("Iyov", 42, kesuvim);
    public static GrandchildTask mishlei = new GrandchildTask("Mishlei",  31, kesuvim);
    public static GrandchildTask rus = new GrandchildTask("Rus",  4, kesuvim);
    public static GrandchildTask shirHashirim = new GrandchildTask("Shie HaShirim",  8, kesuvim);
    public static GrandchildTask koheles = new GrandchildTask("Koheles", 12, kesuvim);
    public static GrandchildTask eichah = new GrandchildTask("Eichah", 5, kesuvim);
    public static GrandchildTask esther = new GrandchildTask("Esther", 10, kesuvim);
    public static GrandchildTask daniel = new GrandchildTask("Daniel", 12, kesuvim);
    public static GrandchildTask ezra = new GrandchildTask("Ezra", 10, kesuvim);
    public static GrandchildTask nechemia = new GrandchildTask("Nechemia",  13, kesuvim);
    public static GrandchildTask[] kesuvimChildren = {divreiHayamimA, divreiHayamimB, tehillim, iyov, mishlei, rus, shirHashirim, koheles, eichah, esther, daniel, ezra, nechemia};

    public static GrandchildTask berachos = new GrandchildTask("Berachos", 9, zeraim);
    public static GrandchildTask peah = new GrandchildTask("Peah", 8, zeraim);
    public static GrandchildTask demai = new GrandchildTask("Demai",  7, zeraim);
    public static GrandchildTask kilayim = new GrandchildTask("Kilayim", 9, zeraim);
    public static GrandchildTask shviis = new GrandchildTask("Shviis", 10, zeraim);
    public static GrandchildTask terumos = new GrandchildTask("Terumos", 11, zeraim);
    public static GrandchildTask maasros = new GrandchildTask("Maasros",5, zeraim);
    public static GrandchildTask maaserSheni = new GrandchildTask("Maaser Sheni",  5, zeraim);
    public static GrandchildTask challah = new GrandchildTask("Challah",  4, zeraim);
    public static GrandchildTask orlah = new GrandchildTask("Orlah",3, zeraim);
    public static GrandchildTask bikkurim = new GrandchildTask("Bikkurim", 4, zeraim);
    public static GrandchildTask[] zeraimChildren = {berachos, peah, demai, kilayim, shviis, terumos, maasros, maaserSheni, challah, orlah, bikkurim};

    public static GrandchildTask shabbos = new GrandchildTask("Shabbos", 24, moed);
    public static GrandchildTask eiruvin = new GrandchildTask("Eiruvin", 10, moed);
    public static GrandchildTask pesachim = new GrandchildTask("Pesachim",  10, moed);
    public static GrandchildTask shekalim = new GrandchildTask("Shekalim", 8, moed);
    public static GrandchildTask yoma = new GrandchildTask("Yoma", 8, moed);
    public static GrandchildTask sukkah = new GrandchildTask("Sukkah",  5, moed);
    public static GrandchildTask beitza = new GrandchildTask("Beitza",  5, moed);
    public static GrandchildTask roshHashana = new GrandchildTask("Roah Hashana", 4, moed);
    public static GrandchildTask taanis = new GrandchildTask("Taanis", 4, moed);
    public static GrandchildTask megilla = new GrandchildTask("Megilla", 4, moed);
    public static GrandchildTask moedKatan = new GrandchildTask("Moed Katan", 3, moed);
    public static GrandchildTask chagiga = new GrandchildTask("Chagiga", 3, moed);
    public static GrandchildTask[] moedChildren = {shabbos, eiruvin, pesachim, shekalim, yoma, sukkah, beitza, roshHashana, taanis, megilla, moedKatan, chagiga};

    public static GrandchildTask yevamos = new GrandchildTask("Yevamos", 16, nashim);
    public static GrandchildTask kesuvos = new GrandchildTask("Kesuvos", 13, nashim);
    public static GrandchildTask nedarim = new GrandchildTask("Nedarim",  11, nashim);
    public static GrandchildTask nazir = new GrandchildTask("Nazir", 9, nashim);
    public static GrandchildTask sottah = new GrandchildTask("Sottah",  9, nashim);
    public static GrandchildTask gittin = new GrandchildTask("Gittin", 9, nashim);
    public static GrandchildTask kiddushin = new GrandchildTask("Kiddushin", 4, nashim);
    public static GrandchildTask[] nashimChildren = {yevamos, kesuvos, nedarim, nazir, sottah, gittin, kiddushin};

    public static GrandchildTask bavaKama = new GrandchildTask("Bava Kama", 10, nezikin);
    public static GrandchildTask bavaMetzia = new GrandchildTask("Bava Metzia", 10, nezikin);
    public static GrandchildTask bavaBasra = new GrandchildTask("Bava Basra", 10, nezikin);
    public static GrandchildTask sanhedrin = new GrandchildTask("Sanhedrin", 11, nezikin);
    public static GrandchildTask makkos = new GrandchildTask("Makkos",  13, nezikin);
    public static GrandchildTask shevuos = new GrandchildTask("Shevuos",  8, nezikin);
    public static GrandchildTask eduyos = new GrandchildTask("Eduyos", 8, nezikin);
    public static GrandchildTask avodaZarah = new GrandchildTask("Avodah Zarah", 5, nezikin);
    public static GrandchildTask avos = new GrandchildTask("Avos", 6, nezikin);
    public static GrandchildTask horayos = new GrandchildTask("Horayos", 3, nezikin);
    public static GrandchildTask[] nezikinChildren = {bavaKama, bavaMetzia, bavaBasra, sanhedrin, makkos, shevuos, eduyos, avodaZarah, avos, horayos};

    public static GrandchildTask zevachim = new GrandchildTask("Zevachim", 14, kodshim);
    public static GrandchildTask menachos = new GrandchildTask("Menachos", 13, kodshim);
    public static GrandchildTask chullin = new GrandchildTask("Chullin", 12, kodshim);
    public static GrandchildTask bechoros = new GrandchildTask("Bechoros",  9, kodshim);
    public static GrandchildTask erchin = new GrandchildTask("Erchin", 9, kodshim);
    public static GrandchildTask temurah = new GrandchildTask("Temurah",  7, kodshim);
    public static GrandchildTask kerisos = new GrandchildTask("Kerisos", 6, kodshim);
    public static GrandchildTask meilah = new GrandchildTask("Meilah", 6, kodshim);
    public static GrandchildTask tamid = new GrandchildTask("Tamid", 7, kodshim);
    public static GrandchildTask middos = new GrandchildTask("Middos", 5, kodshim);
    public static GrandchildTask kinnim = new GrandchildTask("Kinnim", 3, kodshim);
    public static GrandchildTask[] kodshimChildren = {zevachim, menachos, chullin, bechoros, erchin, temurah, kerisos, meilah, tamid, middos, kinnim};

    public static GrandchildTask keilim = new GrandchildTask("Keilim", 30, taharos);
    public static GrandchildTask oholos = new GrandchildTask("Oholos",18, taharos);
    public static GrandchildTask negaim = new GrandchildTask("Negaim", 14, taharos);
    public static GrandchildTask parah = new GrandchildTask("Parah", 12, taharos);
    public static GrandchildTask taharosMesechta = new GrandchildTask("Taharos (Mesechta)", 10, taharos);
    public static GrandchildTask mikvaos = new GrandchildTask("Mikvaos", 10, taharos);
    public static GrandchildTask niddah = new GrandchildTask("Niddah", 10, taharos);
    public static GrandchildTask machshirin = new GrandchildTask("Machshirin", 6, taharos);
    public static GrandchildTask zavim = new GrandchildTask("Zavim", 5, taharos);
    public static GrandchildTask tevulYom = new GrandchildTask("Tevul Yom", 4, taharos);
    public static GrandchildTask yadayim = new GrandchildTask("Yadayim", 4, taharos);
    public static GrandchildTask uktzin = new GrandchildTask("Uktzin", 3, taharos);
    public static GrandchildTask[] taharosChildren = {keilim, oholos, negaim, parah, taharosMesechta, mikvaos, niddah, machshirin, zavim, tevulYom, yadayim, uktzin};

    public static GrandchildTask berachosShas = new GrandchildTask("Berachos (Shas)", 62.5, zeraimShas);
    public static GrandchildTask[] zeraimShasChildren = {berachosShas};

    public static GrandchildTask shabbosShas = new GrandchildTask("Shabbos (Shas)", 156, moedShas);
    public static GrandchildTask eruvinShas = new GrandchildTask("Eruvin (Shas)", 103.5, moedShas);
    public static GrandchildTask pesachimShas = new GrandchildTask("Pesachim (Shas)", 120, moedShas);
    public static GrandchildTask roshHashanaShas = new GrandchildTask("Roah Hashana (Shas)", 33.5, moedShas);
    public static GrandchildTask yomaShas = new GrandchildTask("Yoma (Shas)", 86.5, moedShas);
    public static GrandchildTask sukkahShas = new GrandchildTask("Sukkah (Shas)", 55, moedShas);
    public static GrandchildTask beitzaShas = new GrandchildTask("Beitza (Shas)", 39, moedShas);
    public static GrandchildTask taanisShas = new GrandchildTask("Taanis (Shas)", 29.5, moedShas);
    public static GrandchildTask megillaShas = new GrandchildTask("Megilla (Shas)", 30.5, moedShas);
    public static GrandchildTask moedKatanShas = new GrandchildTask("Moed Katan (Shas)", 27.5, moedShas);
    public static GrandchildTask chagigaShas = new GrandchildTask("Chagiga (Shas)", 25.5, moedShas);
    public static GrandchildTask[] moedShasChildren = {shabbosShas, eruvinShas, pesachimShas, roshHashanaShas, yomaShas, sukkahShas, beitzaShas, taanisShas, megillaShas, moedKatanShas, chagigaShas};

    public static GrandchildTask yevamosShas = new GrandchildTask("Yevamos (Shas)", 121, nashimShas);
    public static GrandchildTask kesuvosShas = new GrandchildTask("Kesuvos (Shas)", 111, nashimShas);
    public static GrandchildTask nedarimShas = new GrandchildTask("Nedarim (Shas)", 90, nashimShas);
    public static GrandchildTask nazirShas = new GrandchildTask("Nazir (Shas)", 65, nashimShas);
    public static GrandchildTask sotahShas = new GrandchildTask("Sotah (Shas)", 48, nashimShas);
    public static GrandchildTask gittinShas = new GrandchildTask("Gittin (Shas)", 89, nashimShas);
    public static GrandchildTask kiddushinShas = new GrandchildTask("Kiddushin (Shas)", 81, nashimShas);
    public static GrandchildTask[] nashimShasChildren = {yevamosShas, kesuvosShas, nedarimShas, nazirShas, sotahShas, gittinShas, kiddushinShas};

    public static GrandchildTask bavaKamaShas = new GrandchildTask("Bava Kama (Shas)", 118, nezikinShas);
    public static GrandchildTask bavaMetziaShas = new GrandchildTask("Bava Metzia (Shas)", 117.5, nezikinShas);
    public static GrandchildTask bavaBasraShas = new GrandchildTask("Bava Basra (Shas)", 175, nezikinShas);
    public static GrandchildTask sanhedrinShas = new GrandchildTask("Sanhedrin (Shas)", 112, nezikinShas);
    public static GrandchildTask makkosShas = new GrandchildTask("Makkos (Shas)", 23, nezikinShas);
    public static GrandchildTask shevuosShas = new GrandchildTask("Shevuos (Shas)", 48, nezikinShas);
    public static GrandchildTask avodahZarahShas = new GrandchildTask("Avodah Zarah (Shas)", 75, nezikinShas);
    public static GrandchildTask horayosShas = new GrandchildTask("Horayos (Shas)", 12.5, nezikinShas);
    public static GrandchildTask[] nezikinShasChildren = {bavaKamaShas, bavaMetziaShas, bavaBasraShas, sanhedrinShas, makkosShas, shevuosShas, avodahZarahShas, horayosShas};

    public static GrandchildTask zevachimShas = new GrandchildTask("Zevachim (Shas)", 119, kodshimShas);
    public static GrandchildTask menachosShas = new GrandchildTask("Menachos (Shas)", 108.5, kodshimShas);
    public static GrandchildTask chullinShas = new GrandchildTask("Chullin (Shas)", 140.5, kodshimShas);
    public static GrandchildTask bechorosShas = new GrandchildTask("Bechoros (Shas)", 59.5, kodshimShas);
    public static GrandchildTask erchinShas = new GrandchildTask("Erchin (Shas)", 32.5, kodshimShas);
    public static GrandchildTask temurahShas = new GrandchildTask("Temurah (Shas)", 32.5, kodshimShas);
    public static GrandchildTask kerisosShas = new GrandchildTask("Kerisos (Shas)", 27, kodshimShas);
    public static GrandchildTask meilahShas = new GrandchildTask("Meilah (Shas)", 20.5, kodshimShas);
    public static GrandchildTask tamidShas = new GrandchildTask("Tamid (Shas)", 8.5, kodshimShas);
    public static GrandchildTask[] kodshimShasChildren = {zevachimShas, menachosShas, chullinShas, bechorosShas, erchinShas, temurahShas, kerisosShas, meilahShas, tamidShas};

    public static GrandchildTask niddahShas = new GrandchildTask("Niddah (Shas)", 71.5, taharosShas);
    public static GrandchildTask[] taharosShasChildren = {niddahShas};

    public static GrandchildTask berachosYerushalmi = new GrandchildTask("Berachos (Yerushalmi)", 58, zeraimYerushalmi);
    public static GrandchildTask peahYerushalmi = new GrandchildTask("Peah (Yerushalmi)", 55, zeraimYerushalmi);
    public static GrandchildTask demaiYerushalmi = new GrandchildTask("Demai (Yerushalmi)", 44, zeraimYerushalmi);
    public static GrandchildTask kilayimYerushalmi = new GrandchildTask("Kilayim (Yerushalmi)", 56, zeraimYerushalmi);
    public static GrandchildTask shviisYerushalmi = new GrandchildTask("Shviis (Yerushalmi)", 56, zeraimYerushalmi);
    public static GrandchildTask terumosYerushalmi = new GrandchildTask("Terumos (Yerushalmi)", 48, zeraimYerushalmi);
    public static GrandchildTask maasrosYerushalmi = new GrandchildTask("Maasros (Yerushalmi)", 20, zeraimYerushalmi);
    public static GrandchildTask maaserSheniYerushalmi = new GrandchildTask("Maaser Sheni (Yerushalmi)", 24, zeraimYerushalmi);
    public static GrandchildTask challahYerushalmi = new GrandchildTask("Challah (Yerushalmi)", 19, zeraimYerushalmi);
    public static GrandchildTask orlahYerushalmi = new GrandchildTask("Orlah (Yerushalmi)", 21, zeraimYerushalmi);
    public static GrandchildTask bikkurimYerushalmi = new GrandchildTask("Bikkurim (Yerushalmi)", 21, zeraimYerushalmi);
    public static GrandchildTask[] zeraimYerushalmiChildren = {berachosYerushalmi, peahYerushalmi, demaiYerushalmi, kilayimYerushalmi, shviisYerushalmi, terumosYerushalmi, maasrosYerushalmi, maaserSheniYerushalmi, challahYerushalmi, orlahYerushalmi, bikkurimYerushalmi};

    public static GrandchildTask shabbosYerushalmi = new GrandchildTask("Shabbos (Yerushalmi)", 141, moedYerushalmi);
    public static GrandchildTask eruvinYerushalmi = new GrandchildTask("Eruvin (Yerushalmi)", 94, moedYerushalmi);
    public static GrandchildTask pesachimYerushalmi = new GrandchildTask("Pesachim (Yerushalmi)", 86, moedYerushalmi);
    public static GrandchildTask yomaYerushalmi = new GrandchildTask("Yoma (Yerushalmi)", 51, moedYerushalmi);
    public static GrandchildTask shekalimYerushalmi = new GrandchildTask("Shekalim (Yerushalmi)", 32, moedYerushalmi);
    public static GrandchildTask sukkahYerushalmi = new GrandchildTask("Sukkah (Yerushalmi)", 49, moedYerushalmi);
    public static GrandchildTask roshHashanaYerushalmi = new GrandchildTask("Rosh Hashana (Yerushalmi)", 36, moedYerushalmi);
    public static GrandchildTask beitzaYerushalmi = new GrandchildTask("Beitza (Yerushalmi)", 46, moedYerushalmi);
    public static GrandchildTask taanisYerushalmi = new GrandchildTask("Taanis (Yerushalmi)", 40, moedYerushalmi);
    public static GrandchildTask megillahYerushalmi = new GrandchildTask("Megillah (Yerushalmi)", 38, moedYerushalmi);
    public static GrandchildTask chagigahYerushalmi = new GrandchildTask("Chagigah (Yerushalmi)", 23, moedYerushalmi);
    public static GrandchildTask moedKatanYerushalmi = new GrandchildTask("Moed Katan (Yerushalmi)", 24, moedYerushalmi);
    public static GrandchildTask[] moedYerushalmiChildren = {shabbosYerushalmi, eruvinYerushalmi, pesachimYerushalmi, yomaYerushalmi, shekalimYerushalmi, sukkahYerushalmi, roshHashanaYerushalmi, beitzaYerushalmi, taanisYerushalmi, megillahYerushalmi, chagigahYerushalmi, moedKatanYerushalmi};

    public static GrandchildTask yevamosYerushalmi = new GrandchildTask("Yevamos (Yerushalmi)", 143, nashimYerushalmi);
    public static GrandchildTask sotahYerushalmi = new GrandchildTask("Sotah (Yerushalmi)", 73, nashimYerushalmi);
    public static GrandchildTask kesuvosYerushalmi = new GrandchildTask("Kesuvos (Yerushalmi)", 121, nashimYerushalmi);
    public static GrandchildTask nedarimYerushalmi = new GrandchildTask("Nedarim (Yerushalmi)", 94, nashimYerushalmi);
    public static GrandchildTask nazirYerushalmi = new GrandchildTask("Nazir (Yerushalmi)", 55, nashimYerushalmi);
    public static GrandchildTask gittinYerushalmi = new GrandchildTask("Gittin (Yerushalmi)", 75, nashimYerushalmi);
    public static GrandchildTask kidushinYerushalmi = new GrandchildTask("Kidushin (Yerushalmi)", 43, nashimYerushalmi);
    public static GrandchildTask[] nashimYerushalmiChildren = {yevamosYerushalmi, sotahYerushalmi, kesuvosYerushalmi, nedarimYerushalmi, nazirYerushalmi, gittinYerushalmi, kidushinYerushalmi};

    public static GrandchildTask bavaKamaYerushalmi = new GrandchildTask("Bava Kama (Yerushalmi)", 85, nezikin);
    public static GrandchildTask bavaMetziaYerushalmi = new GrandchildTask("Bava Metzia (Yerushalmi)", 84, nezikin);
    public static GrandchildTask bavaBasraYerushalmi = new GrandchildTask("Bava Basra (Yerushalmi)", 76, nezikin);
    public static GrandchildTask sanhedrinYerushalmi = new GrandchildTask("Sanhedrin (Yerushalmi)", 89, nezikin);
    public static GrandchildTask shevuosYerushalmi = new GrandchildTask("Shevuos (Yerushalmi)", 58, nezikin);
    public static GrandchildTask avodahZarahYerushalmi = new GrandchildTask("Avodah Zarah (Yerushalmi)", 60, nezikin);
    public static GrandchildTask makkosYerushalmi = new GrandchildTask("Makkos (Yerushalmi)", 28, nezikin);
    public static GrandchildTask horayosYerushalmi = new GrandchildTask("Horayos (Yerushalmi)", 20, nezikin);
    public static GrandchildTask[] nezikinYerushalmiChildren = {bavaKamaYerushalmi, bavaMetziaYerushalmi, bavaBasraYerushalmi, sanhedrinYerushalmi, shevuosYerushalmi, avodahZarahYerushalmi, makkosYerushalmi, horayosYerushalmi};

    public static GrandchildTask niddahYerushalmi = new GrandchildTask("Niddah (Yerushalmi)", 25, taharosYerushalmi);
    public static GrandchildTask[] taharosYerushalmiChildren = {niddahYerushalmi};

    public static GrandchildTask maddah = new GrandchildTask("Maddah", 46, rambam);
    public static GrandchildTask ahava = new GrandchildTask("Ahava", 51, rambam);
    public static GrandchildTask zemanim = new GrandchildTask("Zemanim", 98, rambam);
    public static GrandchildTask nashimRambam = new GrandchildTask("Nashim", 53, rambam);
    public static GrandchildTask kedusha = new GrandchildTask("Kedusha", 53, rambam);
    public static GrandchildTask haflaah = new GrandchildTask("Haflaah", 43, rambam);
    public static GrandchildTask zeraimRambam = new GrandchildTask("Zeraim (Rambam)", 85, rambam);
    public static GrandchildTask avodah = new GrandchildTask("Avodah", 95, rambam);
    public static GrandchildTask korbanos = new GrandchildTask("Korbanos", 45, rambam);
    public static GrandchildTask tahara = new GrandchildTask("Tahara", 144, rambam);
    public static GrandchildTask nezikinRambam = new GrandchildTask("Nezikin (Rambam)", 62, rambam);
    public static GrandchildTask kinyan = new GrandchildTask("Kinyan", 75, rambam);
    public static GrandchildTask mishpatim = new GrandchildTask("Mishpatim", 75, rambam);
    public static GrandchildTask shoftimRambam = new GrandchildTask("Shoftim", 81, rambam);
    public static GrandchildTask[] rambamChildren = {maddah, ahava, zemanim, nashimRambam, kedusha, haflaah, zeraimRambam, avodah, korbanos, tahara, nezikinRambam, kinyan, mishpatim, shoftimRambam};

    public static GrandchildTask orachChaim = new GrandchildTask("Orech Chaim (Tur)", 697, tur);
    public static GrandchildTask yorehDeah = new GrandchildTask("Yoreh Deah (Tur)", 403, tur);
    public static GrandchildTask choshenMishpat = new GrandchildTask("Choshen Mishpat (Tur)", 427, tur);
    public static GrandchildTask evenHaezer = new GrandchildTask("Even Haezer (Tur)", 178, tur);
    public static GrandchildTask[] turChildren = {orachChaim, yorehDeah, choshenMishpat, evenHaezer};

    public static GrandchildTask orachChaimSA = new GrandchildTask("Orech Chaim (Shulchan Aruch)", 697, shulchanAruch);
    public static GrandchildTask yorehDeahSA = new GrandchildTask("Yoreh Deah (Shulchan Aruch)", 403, shulchanAruch);
    public static GrandchildTask choshenMishpatSA = new GrandchildTask("Choshen Mishpat (Shulchan Aruch)", 427, shulchanAruch);
    public static GrandchildTask evenHaezerSA = new GrandchildTask("Even Haezer (Shulchan Aruch)", 178, shulchanAruch);
    public static GrandchildTask[] shulchanAruchChildren = {orachChaimSA, yorehDeahSA, choshenMishpatSA, evenHaezerSA};

    public static GrandchildTask chelek1 = new GrandchildTask("Cheleck Alef" , 127, mishnaBerura);
    public static GrandchildTask chelek2 = new GrandchildTask("Cheleck Beis" , 114, mishnaBerura);
    public static GrandchildTask chelek3 = new GrandchildTask("Cheleck Gimmel" , 103, mishnaBerura);
    public static GrandchildTask chelek4 = new GrandchildTask("Cheleck Daled" , 84, mishnaBerura);
    public static GrandchildTask chelek5 = new GrandchildTask("Cheleck Hei" , 99, mishnaBerura);
    public static GrandchildTask chelek6 = new GrandchildTask("Cheleck Vuv" , 168, mishnaBerura);
    public static GrandchildTask[] mishnaBeruraChildren = {chelek1, chelek2, chelek3, chelek4, chelek5, chelek6};
    public static HashSet<Task> set = new HashSet<>();

    public static void setupTasks(){

        tanach.setChildren(tanachChildren);
        mishnayos.setChildren(mishnayosChildren);
        shas.setChildren(shasChildren);
        yerushalmi.setChildren(yerushalmiChildren);
        rambam.setChildren(rambamChildren);
        tur.setChildren(turChildren);
        shulchanAruch.setChildren(shulchanAruchChildren);
        mishnaBerura.setChildren(mishnaBeruraChildren);

        torah.setChildren(torahChildren);
        neviim.setChildren(neviimChildren);
        kesuvim.setChildren(kesuvimChildren);

        zeraim.setChildren(zeraimChildren);
        moed.setChildren(moedChildren);
        nashim.setChildren(nashimChildren);
        nezikin.setChildren(nezikinChildren);
        kodshim.setChildren(kodshimChildren);
        taharos.setChildren(taharosChildren);

        zeraimShas.setChildren(zeraimShasChildren);
        moedShas.setChildren(moedShasChildren);
        nashimShas.setChildren(nashimShasChildren);
        nezikinShas.setChildren(nezikinShasChildren);
        kodshimShas.setChildren(kodshimShasChildren);
        taharosShas.setChildren(taharosShasChildren);

        zeraimYerushalmi.setChildren(zeraimYerushalmiChildren);
        moedYerushalmi.setChildren(moedYerushalmiChildren);
        nashimYerushalmi.setChildren(nashimYerushalmiChildren);
        nezikinYerushalmi.setChildren(nezikinYerushalmiChildren);
        taharosYerushalmi.setChildren(taharosYerushalmiChildren);
    }

    public static void setupTotals(){

        torah.setTotal();
        neviim.setTotal();
        kesuvim.setTotal();

        zeraim.setTotal();
        moed.setTotal();
        nashim.setTotal();
        nezikin.setTotal();
        kodshim.setTotal();
        taharos.setTotal();

        zeraimShas.setTotal();
        moedShas.setTotal();
        nashimShas.setTotal();
        nezikinShas.setTotal();
        kodshimShas.setTotal();
        taharosShas.setTotal();

        zeraimYerushalmi.setTotal();
        moedYerushalmi.setTotal();
        nashimYerushalmi.setTotal();
        nezikinYerushalmi.setTotal();
        taharosYerushalmi.setTotal();
        tanach.setTotal();
        mishnayos.setTotal();
        shas.setTotal();
        yerushalmi.setTotal();
        rambam.setTotal();
        tur.setTotal();
        shulchanAruch.setTotal();
        mishnaBerura.setTotal();

    }

    public static void setupLearned(){

        torah.setLearned();
        neviim.setLearned();
        kesuvim.setLearned();

        zeraim.setLearned();
        moed.setLearned();
        nashim.setLearned();
        nezikin.setLearned();
        kodshim.setLearned();
        taharos.setLearned();

        zeraimShas.setLearned();
        moedShas.setLearned();
        nashimShas.setLearned();
        nezikinShas.setLearned();
        kodshimShas.setLearned();
        taharosShas.setLearned();

        zeraimYerushalmi.setLearned();
        moedYerushalmi.setLearned();
        nashimYerushalmi.setLearned();
        nezikinYerushalmi.setLearned();
        taharosYerushalmi.setLearned();
        tanach.setLearned();
        mishnayos.setLearned();
        shas.setLearned();
        yerushalmi.setLearned();
        rambam.setLearned();
        tur.setLearned();
        shulchanAruch.setLearned();
        mishnaBerura.setLearned();
    }
    public static void setupSet(){
        addToSet(set, tanach);
        addToSet(set, mishnayos);
        addToSet(set, shas);
        addToSet(set, yerushalmi);
        addToSet(set, rambam);
        addToSet(set, tur);
        addToSet(set, shulchanAruch);
        addToSet(set, mishnaBerura);
    }
    public static void addToSet(HashSet<Task> set, Task t1){
        set.add(t1);
        if (t1.getIsGeneral()){
            Log.i("Task", t1.getName());
            for (Task t : t1.getChildren()){
                addToSet(set, t);
            }
        }
    }
}
