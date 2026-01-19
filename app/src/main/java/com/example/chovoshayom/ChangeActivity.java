package com.example.chovoshayom;

import static com.example.chovoshayom.MainActivity.task;
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

import androidx.activity.OnBackPressedCallback;
import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;

import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;

import com.example.chovoshayom.databinding.ActivityChangeBinding;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;

public class ChangeActivity extends AppCompatActivity {

    private ActivityChangeBinding binding;

    String setting;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        Intent myIntent = getIntent();
        setting = myIntent.getStringExtra("setting");

        binding = ActivityChangeBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());
        OnBackPressedCallback callback = new OnBackPressedCallback(true) {
            @Override
            public void handleOnBackPressed() {
                finish();
                // Custom back press logic
                setEnabled(false);
                getOnBackPressedDispatcher().onBackPressed();
            }
        };
        getOnBackPressedDispatcher().addCallback(this, callback);
        setupButtons(task, setting) ;
    }

    public void setupButtons(Task task, String setting){
        TextView greeting = findViewById(R.id.greeting);
        Button myButton = findViewById(R.id.buttonForChange);

        if (setting.equals("add")){
            String toAdd = "Add: ";
            greeting.setText(toAdd);
            myButton.setText("Add");
            myButton.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    checkInput(setting);
            }});
        }
        else if (setting.equals("remove")){
            String toRemove = "Remove: ";
            greeting.setText(toRemove);
            myButton.setText("Remove");
            myButton.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    checkInput(setting);
                }
            });
        }
    }

    private void checkInput(String setting){
        EditText myEditText = (EditText)  findViewById(R.id.input_box);
        String input = myEditText.getText().toString();
        HashSet<Integer> numsSet = returnInput(input);
        if (setting.equals("add")){
            Methods.setupLearnedList(task, numsSet);
        }
        else if (setting.equals("remove")){
            Methods.removeFromLearnedList(task, numsSet);
        }
        finish();
    }


    private HashSet<Integer> returnInput(String input) {
        ArrayList<String> inputList = splitIntoArrayList(input);
        return getNumbers(inputList);
    }

    private HashSet<Integer> getNumbers(ArrayList<String> inputList) {
        HashSet<Integer> numsSet = new HashSet<>();
        int offset = ((GrandchildTask) task).getOffset();
        for (String s: inputList){
            try {
                int n = Integer.parseInt(s);
                if (n < offset || n > (task.getTotal() - 1 + offset)){
                    continue;
                }
                if (numsSet.add(n)){
                    task.add(1);
                }
            } catch (Exception e){
                if (s.matches("\\d+\\s*-\\s*\\d+")){
                    String[] parts = s.split("-");
                    int start = Integer.parseInt(parts[0].trim());
                    int end = Integer.parseInt(parts[1].trim());
                    if (start > end || start < offset || end > (task.getTotal() - 1 + offset)) {
                        continue;
                    }
                    int[] nums = new int[]{start, end};
                    for (int n: nums){
                        if (numsSet.add(n)){
                            task.add(1);
                        }
                    }
                }
            }
        }
        if (set.isEmpty()){
            AlertDialog.Builder builder = new AlertDialog.Builder(ChangeActivity.this);
            builder.setMessage("Nothing was added.")
                    .setTitle("Error");
            AlertDialog dialog = builder.create();
            dialog.show();
        }
        return numsSet;
    }

    private ArrayList<String> splitIntoArrayList(String input){
        // Split by comma and parse integers
        String[] parts = input.split("\\s*,\\s*");
        ArrayList<String> list = new ArrayList<>(Arrays.asList(parts));

        return list;
    }

    private void saveToPreferences() {
        SharedPreferences sharedPreferences = getSharedPreferences("Tasks", MODE_PRIVATE);
        SharedPreferences.Editor prefsEditor = sharedPreferences.edit();
        Methods.saveToSharedPreferences(prefsEditor);  }
}