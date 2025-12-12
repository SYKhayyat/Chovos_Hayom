package com.example.chovoshayom;

import static com.example.chovoshayom.MainActivity.task;
import static com.example.chovoshayom.TasksSetup.ahava;
import static com.example.chovoshayom.TasksSetup.bereishis;
import static com.example.chovoshayom.TasksSetup.set;
import static com.example.chovoshayom.TasksSetup.setupTotals;

import android.app.Activity;
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
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.Toolbar;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;

import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;

public class StatisticsActivity extends AppCompatActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_statistics);
        Toolbar toolbar = findViewById(R.id.toolbar);
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
        Object[] tasks = set.toArray();
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
            //TODO Stop from wrapping!
        }
        TextView namesView = findViewById(R.id.names);
        namesView.setText(names);
        TextView learnedView = findViewById(R.id.learneds);
        learnedView.setText(learneds);
        TextView totalsView = findViewById(R.id.totals);
        totalsView.setText(totals);
        TextView percentView = findViewById(R.id.percents);
        percentView.setText(percents);
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
        switch (item.getItemId()) {
            case android.R.id.home:
                finish();
                return true;
        }
        return super.onOptionsItemSelected(item);
    }
}