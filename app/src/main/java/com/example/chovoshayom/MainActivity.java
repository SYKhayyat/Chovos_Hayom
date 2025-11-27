package com.example.chovoshayom;

import android.content.Intent;
import android.os.Bundle;
import com.google.gson.Gson;


import com.google.android.material.snackbar.Snackbar;

import androidx.appcompat.app.AppCompatActivity;

import android.util.Log;
import android.view.View;

import androidx.recyclerview.widget.GridLayoutManager;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.example.chovoshayom.databinding.ActivityMainBinding;

import android.view.Menu;
import android.view.MenuItem;
import java.io.Serializable;

public class MainActivity extends AppCompatActivity  implements MyRecyclerViewAdapter.ItemClickListener{

    private ActivityMainBinding binding;
    private RecyclerView recyclerView;

    private RecyclerView.LayoutManager layoutManager;
    MyRecyclerViewAdapter adapter;
    //region Lots of Tasks
    Task tanach = new Task("Tanach", "Perek", 931, tanachChildren);
        Task torah = new Task("Torah", "Perek", 187, torahChildren, tanach);
            Task bereishis = new Task("Bereishis", "Perek", 50, torah);
            Task shemos = new Task()
        Task neviim = new Task("Neviim", "Perek", 380, neviimChildren, tanach);
        Task kesuvim = new Task("Kesuvim", "Perek", 362, true, kesuvimChildren, tanach);
    Task mishnayos = new Task("Mishnayos", "Perek", 525, true, mishnayosChildren);
    Task shas = new Task("Shas", "Daf", 2675, true, mishnayosChildren);
    //        This differs from the commonly accepted number of 2711. That is because of two factors:
//          1. We did not include Shekalim, as it is Yerushalmi.
//          2. We counted an amud at the end of a mesechta as half a daf, not a full daf.
    Task yerushalmi = new Task("Yerushalmi", "Halacha", 2211, true, yerushalmiChildren);
    Task rambam = new Task("Rambam", "Perek", 1000, true, rambamChildren);
    Task tur = new Task("Tur", "Siman", 1704, true, turChildren);
    Task shulchanAruch = new Task("Shulchan Aruch", "Siman", 1704, true, turChildren);
    Task mishnaBerura = new Task("Mishna Berura", "Siman", 697, true, mishnaBeruraChildren);
// endregion
    String[] tanachChildren = {"Torah", "Neviim", "Kesuvim"};
    String[] mishnayosChildren = {"Zeraim", "Moed", "Nashim", "Nezikin", "Kodshim", "Taharos"};
    String[] yerushalmiChildren = {"Zeraim", "Moed", "Nashim", "Nezikin", "Taharos"};
    String[] rambamChildren = {"Sefer Hamitzvos", "Madda", "Ahava", "Zemanim", "Nashim",
            "Kedusha", "Haflaah", "Zeraim", "Avodah",
            "Korbanos", "Tahara", "Nezikin", "Kinyan",
            "Mishpatim", "Shoftim"};
    String[] turChildren = {"Orech Chaim", "Choshen Mishpat", "Yoreh Deah", "Even HaEzer"};
    String[] mishnaBeruraChildren = {"Chelek 1", "Chelek 2", "Chelek 3", "Chelek 4", "Chelek 5", "Chelek 6"};


    Task[] tasksObjects = {
            tanach,
            mishnayos,
            shas,
            yerushalmi,
            rambam,
            tur,
            shulchanAruch,
            mishnaBerura
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);


        String[] tasks = {
                tanach.getName(),
                mishnayos.getName(),
                shas.getName(),
                yerushalmi.getName(),
                rambam.getName(),
                tur.getName(),
                shulchanAruch.getName(),
                mishnaBerura.getName()
        };
        int[] images = {R.drawable.android_tanach,
                R.drawable.android_mishnayos,
                R.drawable.android_shas,
                R.drawable.android_yerushalmi,
                R.drawable.android_rambam,
                R.drawable.android_tur,
                R.drawable.android_shulchan_aruch,
                R.drawable.android_mishna_berurah};
        // set up the RecyclerView
        RecyclerView recyclerView = findViewById(R.id.recycler_view);
        int numberOfColumns = 2;
        recyclerView.setLayoutManager(new GridLayoutManager(this, numberOfColumns));
        adapter = new MyRecyclerViewAdapter(this, tasks, images);
        adapter.setClickListener(this);
        recyclerView.setAdapter(adapter);
    }

    @Override
    public void onItemClick(View view, int position) {
//        Gson gson = new Gson();
//        String myJson = gson.toJson(tasksObjects[position]);
        Intent intent = new Intent(this, DashboardActivity.class);
        intent.putExtra("taskObject", tasksObjects[position]);
        startActivity(intent);
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.menu_main, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        // Handle action bar item clicks here. The action bar will
        // automatically handle clicks on the Home/Up button, so long
        // as you specify a parent activity in AndroidManifest.xml.
        int id = item.getItemId();

        //noinspection SimplifiableIfStatement
        if (id == R.id.action_settings) {
            return true;
        }

        return super.onOptionsItemSelected(item);
    }


}