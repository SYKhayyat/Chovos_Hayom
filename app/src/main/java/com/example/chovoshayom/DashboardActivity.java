package com.example.chovoshayom;

import android.content.Intent;
import android.os.Bundle;

import com.google.android.material.snackbar.Snackbar;

import androidx.appcompat.app.AppCompatActivity;

import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.ProgressBar;
import android.widget.TextView;

import com.example.chovoshayom.databinding.ActivityDashboardBinding;
import com.google.gson.Gson;

public class DashboardActivity extends AppCompatActivity {


//    Intent intent = new Intent();
//    String taskString = intent.getStringExtra("taskObject");
//    Task task = Task.getTaskFromJSON(taskString);


    private ActivityDashboardBinding binding;


    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Intent myIntent = getIntent();

        // Get the MyCustomObject from the intent's extras
        Task task = (Task) myIntent.getSerializableExtra("taskObject");
        binding = ActivityDashboardBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());

        setSupportActionBar(binding.toolbar);

        binding.fab.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                Snackbar.make(view, "Replace with your own action", Snackbar.LENGTH_LONG)
                        .setAnchorView(R.id.fab)
                        .setAction("Action", null).show();
            }
        });



        Button startButton = findViewById(R.id.buttonForMore);
        startButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {

                Intent intent = new Intent(DashboardActivity.this, ChooseActivity.class);
                intent.putExtra("taskObject", task);
                startActivity(intent);
            }
        });

    }



}