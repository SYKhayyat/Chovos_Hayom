package com.example.chovoshayom;

import static com.example.chovoshayom.TasksSetup.*;


import android.content.DialogInterface;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;


import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;

import android.util.DisplayMetrics;
import android.util.Log;
import android.view.View;

import androidx.appcompat.app.AppCompatDelegate;
import androidx.appcompat.widget.Toolbar;
import androidx.recyclerview.widget.GridLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import android.view.Menu;
import android.view.MenuItem;
import android.widget.TextView;

import com.example.chovoshayom.databinding.ActivityMain2Binding;
import com.google.android.material.floatingactionbutton.ExtendedFloatingActionButton;
import com.google.android.material.snackbar.Snackbar;

public class MainActivity extends AppCompatActivity  implements MyRecyclerViewAdapter.ItemClickListener{

    private ActivityMain2Binding binding;
    public static SharedPreferences mPrefs;
    private RecyclerView recyclerView;
    private RecyclerView.LayoutManager layoutManager;
    MyRecyclerViewAdapter adapter;
    public static Task task;
    public int newRunChecker;

    SharedPreferences prefs2;




    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main2);
        newRunChecker = 0;
        Toolbar toolbar = findViewById(R.id.toolbar);
        setSupportActionBar(toolbar);
        ExtendedFloatingActionButton fab = findViewById(R.id.fab);
        prefs2 = getSharedPreferences("Settings", MODE_PRIVATE);
        if (prefs2.getInt("Day_Night", -1) == 1){
            AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_YES);
        }
        else {
            AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM);
        }
        task = all;
        fab.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                String allFinished = Methods.getFinished(task);
                Snackbar snackbar = Snackbar.make(view, allFinished, Snackbar.LENGTH_LONG)
                        .setAction("Action", null);
                View snackbarView = snackbar.getView();
                TextView textView = snackbarView.findViewById(com.google.android.material.R.id.snackbar_text);
                textView.setMaxLines(10); // Allow up to 5 lines
                snackbar.show();
                Methods.clearSet();
            }
        });
        mPrefs = getPreferences(MODE_PRIVATE);
//        if (newRunChecker == 0) {
            setupTasksOldAndNew();
//        }
        savePreferences();
        setupRecycler();
    }

    private void setupTasksOldAndNew() {
        SharedPreferences prefs = getSharedPreferences("Tasks", MODE_PRIVATE);
        TasksSetup.setupTasks();
        TasksSetup.setupTotals();
        TasksSetup.setupSet();
        if (! prefs.getAll().isEmpty()) {
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
        SharedPreferences sharedPreferences = getSharedPreferences("Tasks", MODE_PRIVATE);
        SharedPreferences.Editor prefsEditor = sharedPreferences.edit();
        Methods.saveToSharedPreferences(prefsEditor);
    }
    public void setupRecycler(){

        // Get DisplayMetrics instance
        DisplayMetrics displayMetrics = getResources().getDisplayMetrics();
        int widthPx = displayMetrics.widthPixels;
        float density = displayMetrics.density; // density = px/dp
        float widthDp = widthPx / density;
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
                R.drawable.android_arbaah_turim,
                R.drawable.android_shulchan_aruch,
                R.drawable.android_mishna_berura};
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
        task = task.getChildren()[position];
        newRunChecker = 1;
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
        } else if (itemId == R.id.calculate){
            showCalculate();
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

    private void saveToPreferences() {
        SharedPreferences sharedPreferences = getSharedPreferences("Tasks", MODE_PRIVATE);
        SharedPreferences.Editor prefsEditor = sharedPreferences.edit();
        Methods.saveToSharedPreferences(prefsEditor);
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setMessage("Your progress has been saved!")
                .setTitle("Saved!");
        AlertDialog dialog = builder.create();
        dialog.show();
    }

    private void showCalculate() {
        Intent intent = new Intent(this, CalculateActivity.class);
        startActivity(intent);
    }

    private void showStatistics() {
        Intent intent = new Intent(this, StatisticsActivity.class);
        startActivity(intent);
    }


    private void resetAll() {
        if (prefs2.getInt("Read_Only", -1) != 1){
            Log.i("Reset", "Reset");
            AlertDialog.Builder builder = new AlertDialog.Builder(this);
            builder.setMessage("This will reset everything to zero!")
                    .setTitle("Are you sure?");
            builder.setPositiveButton("Yes", new DialogInterface.OnClickListener() {
                public void onClick(DialogInterface dialog, int id) {
                    SharedPreferences sharedPreferences = getSharedPreferences("Tasks", MODE_PRIVATE);
                    SharedPreferences.Editor prefsEditor = sharedPreferences.edit();
                    Methods.resetAll();
                    Methods.saveToSharedPreferences(prefsEditor);
                }
            });
            builder.setNegativeButton("No", new DialogInterface.OnClickListener() {
                public void onClick(DialogInterface dialog, int id) {
                }
            });
            AlertDialog dialog = builder.create();
            dialog.show();}
        else {
            AlertDialog.Builder builder = new AlertDialog.Builder(this);
            builder.setMessage("Read Only mode is on.")
                    .setTitle("Not Enabled!");
            AlertDialog dialog = builder.create();
            dialog.show();}
    }

    private void showSettings() {
        Intent intent = new Intent(this, SettingsActivity.class);
        startActivity(intent);
    }
    private void showAbout() {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setMessage("Chovos Hayom is a simple app, designed by Shaul Khayyat, which allows you to keep track of your learning and calculate when your next siyum will be.")
                .setTitle("Chovos Hayom");
        AlertDialog dialog = builder.create();
        dialog.show();
    }
}