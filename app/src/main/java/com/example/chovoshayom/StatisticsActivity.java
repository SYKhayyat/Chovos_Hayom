package com.example.chovoshayom;

import static com.example.chovoshayom.MainActivity.task;
import static com.example.chovoshayom.TasksSetup.ahava;
import static com.example.chovoshayom.TasksSetup.all;
import static com.example.chovoshayom.TasksSetup.bereishis;
import static com.example.chovoshayom.TasksSetup.set;
import static com.example.chovoshayom.TasksSetup.setupTotals;

import android.app.Activity;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.util.DisplayMetrics;
import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.TextView;

import androidx.activity.EdgeToEdge;
import androidx.appcompat.app.ActionBar;
import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.app.AppCompatDelegate;
import androidx.appcompat.widget.Toolbar;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;

import com.google.android.material.floatingactionbutton.ExtendedFloatingActionButton;
import com.google.android.material.snackbar.Snackbar;

import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashSet;

public class StatisticsActivity extends AppCompatActivity {
    SharedPreferences prefs2;


    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_statistics);
        Toolbar toolbar = findViewById(R.id.toolbar);
        prefs2 = getSharedPreferences("Settings", MODE_PRIVATE);
        if (prefs2.getInt("Day_Night", -1) == 1){
            AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_YES);
        }
        else {
            AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM);
        }
        ExtendedFloatingActionButton fab = findViewById(R.id.fab);
        fab.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                String allFinished = Methods.getFinished(task);
                Methods.clearSet();
                Snackbar snackbar = Snackbar.make(view, allFinished, Snackbar.LENGTH_LONG)
                        .setAction("Action", null);
                View snackbarView = snackbar.getView();
                TextView textView = snackbarView.findViewById(com.google.android.material.R.id.snackbar_text);
                textView.setMaxLines(10); // Allow up to 5 lines
                snackbar.show();
            }
        });
        setSupportActionBar(toolbar);
        ActionBar actionBar = getSupportActionBar();
        actionBar.setDisplayHomeAsUpEnabled(true);
        setColumns();
        refreshStatistics();
        printStatistics();
    }

    private void setColumns() {
        TextView namesView = findViewById(R.id.names);
        TextView learnedView = findViewById(R.id.learneds);
        TextView totalsView = findViewById(R.id.totals);
        TextView percentView = findViewById(R.id.percents);
        DisplayMetrics displayMetrics = getResources().getDisplayMetrics();
        int widthPx = displayMetrics.widthPixels;
        float density = displayMetrics.density; // density = px/dp
        float widthDp = widthPx / density;
        int screenWidthDp = Math.round(widthDp);
        if (screenWidthDp < 250){
            learnedView.setVisibility(View.GONE);
            totalsView.setVisibility(View.GONE);
            percentView.setVisibility(View.VISIBLE);
        }
        else if (screenWidthDp < 400){
            learnedView.setVisibility(View.VISIBLE);
            totalsView.setVisibility(View.VISIBLE);
            percentView.setVisibility(View.GONE);
        }
        else{
            learnedView.setVisibility(View.VISIBLE);
            totalsView.setVisibility(View.VISIBLE);
            percentView.setVisibility(View.VISIBLE);
        }
    }

    private void refreshStatistics() {
            SharedPreferences prefs = getSharedPreferences("Tasks", MODE_PRIVATE);
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
    private void loadLearned(Task t, SharedPreferences prefs) {
        double learned = Double.longBitsToDouble(prefs.getLong(t.getName(), Double.doubleToLongBits(0)));
        t.reset(learned);
        setupTotals();
    }

    private void printStatistics() {
        HashSet<Task> taskSet = Methods.getCurrentSet(task);
        Object[] tasks = taskSet.toArray();
        Arrays.sort(tasks);
        String names = "Names";
        String learneds = "Learned:";
        String totals = "Total:";
        String percents = "Percent:";
        for (Object t: tasks){
            Task task = ((Task) t);
            names += "\n" + task.getName();
            learneds += "\n" + String.valueOf(task.getLearned());
            totals += "\n" + String.valueOf(task.getTotal());
            percents += "\n" + String.valueOf(task.getPercentage());
        }
        TextView namesView = findViewById(R.id.names);
        namesView.setText(names);
        TextView learnedView = findViewById(R.id.learneds);
        learnedView.setText(learneds);
        TextView totalsView = findViewById(R.id.totals);
        totalsView.setText(totals);
        TextView percentView = findViewById(R.id.percents);
        percentView.setText(percents);
        Methods.clearCurrentSet();
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
        }
        else if (itemId == android.R.id.home){
            Intent returnIntent = new Intent();
            if (task.getParent() != null){
                task = task.getParent();}
            TasksSetup.setupLearned();
            Log.i("Bereishis", String.valueOf(bereishis.getLearned()));
            returnIntent.putExtra("result",task);
            setResult(Activity.RESULT_OK,returnIntent);
            Log.i("Task", task.getName());
            finish();
            return true;
        }
        else if (itemId == R.id.action_save) {
            saveToPreferences();
            return true;
        } else if (itemId == R.id.calculate) {
            showCalculate();
            return true;
        }else if (itemId == R.id.action_reset_stats) {
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
    private void showCalculate() {
        Intent intent = new Intent(this, CalculateActivity.class);
        startActivity(intent);
    }
    private void showStatistics() {
        Intent intent = new Intent(this, StatisticsActivity.class);
        startActivity(intent);
    }

    private void saveToPreferences() {
        SharedPreferences sharedPreferences = getSharedPreferences("Tasks", MODE_PRIVATE);
        SharedPreferences.Editor prefsEditor = sharedPreferences.edit();
        Methods.saveToSharedPreferences(prefsEditor);
    }

    private void resetAll() {
        if (prefs2.getInt("Read_Only", -1) != 1){
            AlertDialog.Builder builder = new AlertDialog.Builder(this);
            builder.setMessage("This will reset everything to zero!")
                    .setTitle("Are you sure?");
            builder.setPositiveButton("Yes", new DialogInterface.OnClickListener() {
                public void onClick(DialogInterface dialog, int id) {
                    SharedPreferences sharedPreferences = getSharedPreferences("Tasks", MODE_PRIVATE);
                    SharedPreferences.Editor prefsEditor = sharedPreferences.edit();
                    Methods.saveToSharedPreferences(prefsEditor, 0);
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
            dialog.show();
        }

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