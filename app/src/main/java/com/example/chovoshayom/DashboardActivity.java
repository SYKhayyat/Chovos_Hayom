package com.example.chovoshayom;

import static com.example.chovoshayom.MainActivity.*;
import static com.example.chovoshayom.TasksSetup.all;
import static com.example.chovoshayom.TasksSetup.bereishis;
import static com.example.chovoshayom.TasksSetup.set;

import android.app.Activity;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;

import com.google.android.material.floatingactionbutton.ExtendedFloatingActionButton;
import com.google.android.material.floatingactionbutton.FloatingActionButton;
import com.google.android.material.snackbar.Snackbar;

import androidx.annotation.NonNull;
import androidx.appcompat.app.ActionBar;
import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.app.AppCompatDelegate;
import androidx.appcompat.view.menu.MenuView;
import androidx.recyclerview.widget.GridLayoutManager;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import android.util.Log;
import androidx.appcompat.widget.Toolbar;


import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.ProgressBar;
import android.widget.TextView;
import com.example.chovoshayom.MainActivity.*;

import com.example.chovoshayom.databinding.ActivityDashboard2Binding;
import com.google.gson.Gson;

import java.util.ArrayList;

import kotlinx.coroutines.scheduling.TasksKt;

public class DashboardActivity extends AppCompatActivity implements MyRecyclerViewAdapterDashboard.ItemClickListener {



    private ActivityDashboard2Binding binding;


    private RecyclerView recyclerView;
    SharedPreferences prefs2;

    private RecyclerView.LayoutManager layoutManager;
    MyRecyclerViewAdapterDashboard adapter;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Intent myIntent = getIntent();
        binding = ActivityDashboard2Binding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());
        Toolbar toolbar = findViewById(R.id.toolbar);
        setSupportActionBar(toolbar);
        ActionBar actionBar = getSupportActionBar();
        assert actionBar != null;
        actionBar.setDisplayHomeAsUpEnabled(true);
        prefs2 = getSharedPreferences("Settings", MODE_PRIVATE);
        if (prefs2.getInt("Day_Night", -1) == 1){
            AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_YES);
        }
        else {
            AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM);
        }
        setName();
        setPercent();
        setProgressBar();
        setFraction();
        setButtons();
        setRecycler();
        ExtendedFloatingActionButton fab = findViewById(R.id.fab);
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
    }

    private void setName() {
        TextView name = (TextView) findViewById(R.id.name);
        name.setText(task.getName());
    }

    private void setPercent() {
        TextView percent = findViewById(R.id.percent);
        String percentString = task.getPercentage() + "%";
        percent.setText(percentString);
    }

    private void setProgressBar() {
        ProgressBar progressBar = findViewById(R.id.progressBar);
        progressBar.setMax((int) task.getTotal());
        progressBar.setProgress((int) task.getLearned());
    }

    private void setFraction() {
        TextView fraction = findViewById(R.id.fraction);
        String fractionText = task.getLearned() + " / " + task.getTotal();
        fraction.setText(fractionText);
    }

    private void setButtons() {
        Button add = findViewById(R.id.buttonForMore);
        Button reset = findViewById(R.id.buttonToReset);
        if (! task.getIsGeneral() && prefs2.getInt("Read_Only", -1) != 1){
            add.setVisibility(View.VISIBLE);
            add.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    openInputActivity("add");
                }
            });
            reset.setVisibility(View.VISIBLE);
            reset.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    openInputActivity("reset");
                }
            });
        }
        else {
            add.setVisibility(View.GONE);
            reset.setVisibility(View.GONE);
        }

    }

    public void openInputActivity(String setting){
        Intent intent = new Intent(this, ChangeActivity.class);
        intent.putExtra("taskObject", task);
        intent.putExtra("setting", setting);
        startActivityForResult(intent, 1);
        Log.i("hello", "called");
    }
    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        Log.i("hello", "returned");

        if (requestCode == 1) {
            if (resultCode == Activity.RESULT_OK) {
                Log.i("Task", String.valueOf(task.getLearned()));
                TasksSetup.setupLearned();
                setName();
                setPercent();
                setProgressBar();
                setFraction();
                setButtons();
                setRecycler();
            }
            if (resultCode == Activity.RESULT_CANCELED) {
                Log.i("Result", "Cancelled");
            }
        }
    }

    private void setRecycler() {
        RecyclerView recyclerView = findViewById(R.id.recycler_view_dashboard);
        if (task.getIsGeneral()){
            recyclerView.setVisibility(View.VISIBLE);
            populateRecyclerView();
        }
        else{
            recyclerView.setVisibility(View.GONE);
        }
    }

    private void populateRecyclerView() {
        RecyclerView recyclerView = findViewById(R.id.recycler_view_dashboard);
        ImageView myImage = findViewById(R.id.itemImage);
        recyclerView.setLayoutManager(new LinearLayoutManager(this));
        adapter = new MyRecyclerViewAdapterDashboard(this, ((ParentTask) task).getChildrenStrings());
        adapter.setClickListener(this);
        recyclerView.setAdapter(adapter);
    }


    public void onItemClick(View view, int position) {
        Intent intent = new Intent(this, DashboardActivity.class);
        task = task.getChildren()[position];
        startActivityForResult(intent, 1);
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.menu_other, menu);
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
            return true;}
        else if (itemId == R.id.action_reset_specific) {
                resetSpecific();
                return true;}
        else if (itemId == R.id.action_reset_stats) {
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
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setMessage("Your progress has been saved!")
                .setTitle("Saved!");
        AlertDialog dialog = builder.create();
        dialog.show();    }


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
    private void resetSpecific() {
        askAndReset(task);
    }

    private void resetAll() {
        askAndReset(all);
    }

    private void askAndReset(Task t) {
        if (prefs2.getInt("Read_Only", -1) != 1){
            AlertDialog.Builder builder = new AlertDialog.Builder(this);
            builder.setMessage("This will reset everything to zero!")
                    .setTitle("Are you sure?");
            builder.setPositiveButton("Yes", new DialogInterface.OnClickListener() {
                public void onClick(DialogInterface dialog, int id) {
                    SharedPreferences sharedPreferences = getSharedPreferences("Tasks", MODE_PRIVATE);
                    SharedPreferences.Editor prefsEditor = sharedPreferences.edit();
                    if (t.equals(all)){
                        Methods.resetAll();
                    }
                    else {
                        Methods.resetSpecific(t);
                    }
                    TasksSetup.setupLearned();
                    Methods.saveToSharedPreferences(prefsEditor);
                    setPercent();
                    setProgressBar();
                    setFraction();
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

}