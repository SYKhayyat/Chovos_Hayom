package com.example.chovoshayom;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;

import com.google.android.material.snackbar.Snackbar;

import androidx.appcompat.app.AppCompatActivity;

import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;

import com.example.chovoshayom.databinding.ActivityChangeBinding;

public class ChangeActivity extends AppCompatActivity {

    private ActivityChangeBinding binding;

    Task task;
    String setting;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        Intent myIntent = getIntent();
        task = (Task) myIntent.getSerializableExtra("taskObject");
        setting = myIntent.getStringExtra("setting");

        binding = ActivityChangeBinding.inflate(getLayoutInflater());
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
        setupButtons(task, setting);
    }

    public void setupButtons(Task task, String setting){
        Button myButton = findViewById(R.id.buttonForChange);
        EditText myEditText = (EditText)  findViewById(R.id.input_box);

        if (setting.equals("add")){
            myButton.setText("Add");
            myButton.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    String input = myEditText.getText().toString();
                    double amount = Double.parseDouble(input);
                    Log.i("TaskA", input);
                    Log.i("TaskB", String.valueOf(amount));
                    task.add(amount);
                    Log.i("TaskC", String.valueOf(task.getLearned()));
                    Intent returnIntent = new Intent();
                    returnIntent.putExtra("result",task);
                    setResult(Activity.RESULT_OK,returnIntent);
                    finish();
                }
            });
        }
        else if (setting.equals("reset")){
            myButton.setText("Reset");
            myButton.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    String input = myEditText.getText().toString();
                    double amount = Double.parseDouble(input);
                    task.reset(amount);
                    Intent returnIntent = new Intent();
                    returnIntent.putExtra("result",task);
                    setResult(Activity.RESULT_OK,returnIntent);
                    finish();
                }
            });
        }
    }
}