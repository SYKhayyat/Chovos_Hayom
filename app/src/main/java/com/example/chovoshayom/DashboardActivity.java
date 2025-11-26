package com.example.chovoshayom;

import android.content.Intent;
import android.os.Bundle;

import com.google.android.material.snackbar.Snackbar;

import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.GridLayoutManager;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.ProgressBar;
import android.widget.TextView;

import com.example.chovoshayom.databinding.ActivityDashboardBinding;
import com.google.gson.Gson;

import kotlinx.coroutines.scheduling.TasksKt;

public class DashboardActivity extends AppCompatActivity implements MyRecyclerViewAdapterDashboard.ItemClickListener {



    private ActivityDashboardBinding binding;

    private RecyclerView recyclerView;

    private RecyclerView.LayoutManager layoutManager;
    MyRecyclerViewAdapterDashboard adapter;


    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Intent myIntent = getIntent();
        Task task = (Task) myIntent.getSerializableExtra("taskObject");
        Log.i("Hello", task.getName());

        binding = ActivityDashboardBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());
        setName(task);
        setPercent(task);
        setProgressBar(task);
        setFraction(task);
        setButtons(task);
        setRecycler(task);

        setSupportActionBar(binding.toolbar);

        binding.fab.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                Snackbar.make(view, "Replace with your own action", Snackbar.LENGTH_LONG)
                        .setAnchorView(R.id.fab)
                        .setAction("Action", null).show();
            }
        });
    }



    private void setName(Task task) {
        TextView name = (TextView) findViewById(R.id.name);
        name.setText(task.getName());
    }

    private void setPercent(Task task) {
        TextView percent = findViewById(R.id.percent);
        String percentString = task.getPercentage() + "%";
        percent.setText(percentString);
    }

    private void setProgressBar(Task task) {
        ProgressBar progressBar = findViewById(R.id.progressBar);
        progressBar.setMax((int) task.getTotal());
        progressBar.setProgress((int) task.getLearned());
    }

    private void setFraction(Task task) {
        TextView fraction = findViewById(R.id.fraction);
        String fractionText = task.getLearned() + " / " + task.getTotal();
        fraction.setText(fractionText);
    }

    private void setButtons(Task task) {
        if (! task.getIsGeneral()){
            Button add = findViewById(R.id.buttonForMore);
            add.setVisibility(View.VISIBLE);
            Button reset = findViewById(R.id.buttonToReset);
            reset.setVisibility(View.VISIBLE);
            RecyclerView recyclerView = findViewById(R.id.recycler_view);
            reset.setVisibility(View.GONE);
        }
    }

    private void setRecycler(Task task) {
        if (task.getIsGeneral()){
            Button add = findViewById(R.id.buttonForMore);
            add.setVisibility(View.GONE);
            Button reset = findViewById(R.id.buttonToReset);
            reset.setVisibility(View.GONE);
            RecyclerView recyclerView = findViewById(R.id.recycler_view);
            reset.setVisibility(View.VISIBLE);
            populateRecyclerView(task);
        }
    }

    private void populateRecyclerView(Task task) {
        RecyclerView recyclerView = findViewById(R.id.recycler_view_dashboard);
        recyclerView.setLayoutManager(new LinearLayoutManager(this));
        adapter = new MyRecyclerViewAdapterDashboard(this, task.getChildren());
        adapter.setClickListener(this);
        recyclerView.setAdapter(adapter);
    }


    public void onItemClick(View view, int position) {
        Log.i("Note", Integer.toString(position));
    }

}