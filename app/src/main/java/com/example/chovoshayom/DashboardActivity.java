package com.example.chovoshayom;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;

import com.google.android.material.snackbar.Snackbar;

import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.view.menu.MenuView;
import androidx.recyclerview.widget.GridLayoutManager;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.ProgressBar;
import android.widget.TextView;

import com.example.chovoshayom.databinding.ActivityDashboard2Binding;
import com.google.gson.Gson;

import kotlinx.coroutines.scheduling.TasksKt;

public class DashboardActivity extends AppCompatActivity implements MyRecyclerViewAdapterDashboard.ItemClickListener {



    private ActivityDashboard2Binding binding;

    private RecyclerView recyclerView;

    private RecyclerView.LayoutManager layoutManager;
    MyRecyclerViewAdapterDashboard adapter;

    Task task;


    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Intent myIntent = getIntent();
        task = (Task) myIntent.getSerializableExtra("taskObject");
        binding = ActivityDashboard2Binding.inflate(getLayoutInflater());
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
        Button add = findViewById(R.id.buttonForMore);
        Button reset = findViewById(R.id.buttonToReset);
        if (! task.getIsGeneral()){
            add.setVisibility(View.VISIBLE);
            add.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    openInputActivity(task, "add");
                }
            });
            reset.setVisibility(View.VISIBLE);
            reset.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    openInputActivity(task, "reset");
                }
            });
        }
        else {
            add.setVisibility(View.GONE);
            reset.setVisibility(View.GONE);
        }

    }
    public void openInputActivity(Task task, String setting){
        int LAUNCH_SECOND_ACTIVITY = 1;
        Intent intent = new Intent(this, ChangeActivity.class);
        intent.putExtra("taskObject", task);
        intent.putExtra("setting", setting);
        startActivityForResult(intent, LAUNCH_SECOND_ACTIVITY);
        Log.i("hello", "called");
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        Log.i("hello", "returned");

        if (requestCode == 1) {
            if (resultCode == Activity.RESULT_OK) {
                task = (Task) data.getSerializableExtra("result");
                Log.i("Task", String.valueOf(task.getLearned()));
                TasksSetup.setupLearned();
                setName(task);
                setPercent(task);
                setProgressBar(task);
                setFraction(task);
                setButtons(task);
                setRecycler(task);
            }
            if (resultCode == Activity.RESULT_CANCELED) {
                Log.i("Result", "Cancelled");
            }
        }
    }

    private void setRecycler(Task task) {
        RecyclerView recyclerView = findViewById(R.id.recycler_view_dashboard);
        if (task.getIsGeneral()){
            recyclerView.setVisibility(View.VISIBLE);
            populateRecyclerView(task);
        }
        else{
            recyclerView.setVisibility(View.GONE);
        }
    }

    private void populateRecyclerView(Task task) {
        RecyclerView recyclerView = findViewById(R.id.recycler_view_dashboard);
        ImageView myImage = findViewById(R.id.itemImage);
        recyclerView.setLayoutManager(new LinearLayoutManager(this));
        adapter = new MyRecyclerViewAdapterDashboard(this, ((ParentTask) task).getChildrenStrings());
        adapter.setClickListener(this);
        recyclerView.setAdapter(adapter);
    }


    public void onItemClick(View view, int position) {
        Intent intent = new Intent(this, DashboardActivity.class);
        Task[] tasksObjects = ((ParentTask) task).getChildren();
        intent.putExtra("taskObject", tasksObjects[position]);
        startActivity(intent);
    }

}