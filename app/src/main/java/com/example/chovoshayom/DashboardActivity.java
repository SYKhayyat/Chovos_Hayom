package com.example.chovoshayom;

import static com.example.chovoshayom.MainActivity.*;
import static com.example.chovoshayom.TasksSetup.bereishis;
import static com.example.chovoshayom.TasksSetup.set;

import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;

import com.google.android.material.snackbar.Snackbar;

import androidx.annotation.NonNull;
import androidx.appcompat.app.ActionBar;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.view.menu.MenuView;
import androidx.recyclerview.widget.GridLayoutManager;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import android.util.Log;
import androidx.appcompat.widget.Toolbar;


import android.view.MenuItem;
import android.view.View;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.ProgressBar;
import android.widget.TextView;
import com.example.chovoshayom.MainActivity.*;

import com.example.chovoshayom.databinding.ActivityDashboard2Binding;
import com.google.gson.Gson;

import kotlinx.coroutines.scheduling.TasksKt;

public class DashboardActivity extends AppCompatActivity implements MyRecyclerViewAdapterDashboard.ItemClickListener {



    private ActivityDashboard2Binding binding;


    private RecyclerView recyclerView;

    private RecyclerView.LayoutManager layoutManager;
    MyRecyclerViewAdapterDashboard adapter;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Intent myIntent = getIntent();
        binding = ActivityDashboard2Binding.inflate(getLayoutInflater());
        Toolbar toolbar = findViewById(R.id.toolbar);
        setSupportActionBar(toolbar);
        ActionBar actionBar = getSupportActionBar();
        actionBar.setDisplayHomeAsUpEnabled(true);
        setContentView(binding.getRoot());
        setName();
        setPercent();
        setProgressBar();
        setFraction();
        setButtons();
        setRecycler();

        binding.fab.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                saveToSharedPreferences();
                Snackbar.make(view, "Your changes have been saved", Snackbar.LENGTH_LONG)
                        .setAnchorView(R.id.fab)
                        .setAction("Action", null).show();
            }
        });
    }

    private void saveToSharedPreferences() {
        SharedPreferences sharedPreferences = getSharedPreferences("Tasks", MODE_PRIVATE);
        SharedPreferences.Editor prefsEditor = sharedPreferences.edit();
        prefsEditor.putLong(task.getName(), Double.doubleToRawLongBits(task.getLearned()));
        prefsEditor.putString("Hello", "World");
        prefsEditor.commit();
        for (Task t: set){
            prefsEditor.putLong(t.getName(), Double.doubleToRawLongBits(t.getLearned()));
            prefsEditor.commit();
        }
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
        if (! task.getIsGeneral()){
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
                Log.i("Bereishis1", String.valueOf(bereishis.getLearned()));
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
    public boolean onOptionsItemSelected(@NonNull MenuItem item) {
        switch (item.getItemId()) {
            case android.R.id.home:
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
        return super.onOptionsItemSelected(item);
    }

}