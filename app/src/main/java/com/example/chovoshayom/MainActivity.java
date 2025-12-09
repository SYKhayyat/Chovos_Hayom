package com.example.chovoshayom;

import static com.example.chovoshayom.TasksSetup.*;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;


import androidx.appcompat.app.AppCompatActivity;

import android.util.DisplayMetrics;
import android.util.Log;
import android.view.View;

import androidx.recyclerview.widget.GridLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import android.view.Menu;
import android.view.MenuItem;
import android.widget.Toast;

import com.example.chovoshayom.databinding.ActivityMain2Binding;
import com.google.android.material.floatingactionbutton.FloatingActionButton;
import com.google.android.material.snackbar.Snackbar;
import com.google.gson.Gson;

import java.util.ArrayList;

public class MainActivity extends AppCompatActivity  implements MyRecyclerViewAdapter.ItemClickListener{

    private ActivityMain2Binding binding;


    public static SharedPreferences mPrefs;

    private RecyclerView recyclerView;

    private RecyclerView.LayoutManager layoutManager;
    MyRecyclerViewAdapter adapter;

    public static Task task;

    public static ParentTask[] tasksObjects= {
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
        setContentView(R.layout.activity_main2);
        FloatingActionButton fab = findViewById(R.id.fab);
        fab.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                ArrayList<String> finished = new ArrayList<>();
                TasksSetup.setupSet();
                for (Task t: set){
                    if (t.getLearned() == t.getTotal()){
                        finished.add(t.getName());
                    }
                }
                String allFinished = "You have finished " + finished.size() + " items.";
                for (String s: finished){
                    allFinished += "\n" + s;
                }
                Snackbar.make(view, allFinished, Snackbar.LENGTH_LONG)
                        .setAction("Action", null).show();
            }
        });
        mPrefs = getPreferences(MODE_PRIVATE);
        setupTasksOldAndNew();
        savePreferences();
        setupRecycler();
    }

    private void setupTasksOldAndNew() {
        SharedPreferences prefs = getSharedPreferences("Tasks", MODE_PRIVATE);
        TasksSetup.setupTasks();
        TasksSetup.setupTotals();
        TasksSetup.setupSet();
        if (prefs.getAll().isEmpty()) {
            Log.i("Empty", "Empty");
        } else {
            Log.i("full", "full");
            for (Task t: set){
                loadLearned(t, prefs);
            }
        }
    }
    private static void loadLearned(Task t, SharedPreferences prefs) {
        double learned = Double.longBitsToDouble(prefs.getLong(t.getName(), Double.doubleToLongBits(0)));
        t.reset(learned);
        setupTotals();
    }
    private void savePreferences() {
        TasksSetup.setupSet();
        for (Task t: set){
            SharedPreferences sharedPreferences = getSharedPreferences("Tasks", MODE_PRIVATE);
            SharedPreferences.Editor prefsEditor = sharedPreferences.edit();
            prefsEditor.putLong(t.getName(), Double.doubleToRawLongBits(t.getLearned()));
            prefsEditor.commit();
        }
    }
    public void setupRecycler(){

        // Get DisplayMetrics instance
        DisplayMetrics displayMetrics = getResources().getDisplayMetrics();

        // Screen width in pixels
        int widthPx = displayMetrics.widthPixels;

        // Convert pixels to dp
        float density = displayMetrics.density; // density = px/dp
        float widthDp = widthPx / density;

        // Store as variable
        int screenWidthDp = Math.round(widthDp);
        if (screenWidthDp < 200){
            screenWidthDp = 200;
        }
        Log.i("width", String.valueOf(screenWidthDp));
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
        int numberOfColumns = screenWidthDp/200;
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
        task = tasksObjects[position];
        intent.putExtra("taskObject", position);
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
        int itemId = item.getItemId();
        if (itemId == R.id.action_statistics) {
            showStatistics();
            return true;
        } else if (itemId == R.id.action_save) {
            saveToPreferences();
            return true;
        } else if (itemId == R.id.action_reset_stats) {
            resetAll();
            return true;
        } else if (itemId == R.id.action_settings) {
            showSettings();
            return true;
        } else if (itemId == R.id.action_about) {
            showAbout();
            return true;
        }
        return super.onOptionsItemSelected(item);
    }

    private void showStatistics() {
        Intent intent = new Intent(this, StatisticsActivity.class);
        startActivity(intent);
    }

    private void saveToPreferences() {
    }

    private void resetAll() {
    }

    private void showSettings() {
    }

    private void showAbout() {
    }
}