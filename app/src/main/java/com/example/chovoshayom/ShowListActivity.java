package com.example.chovoshayom;

import static com.example.chovoshayom.MainActivity.task;

import android.content.DialogInterface;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;

import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import android.view.View;
import android.widget.ProgressBar;
import android.widget.TextView;

import com.example.chovoshayom.databinding.ActivityShowListBinding;

import java.util.ArrayList;

public class ShowListActivity extends AppCompatActivity implements MyRecyclerViewAdapterList.ItemClickListener{

    private ActivityShowListBinding binding;
    MyRecyclerViewAdapterList adapter;
    private int[] list1;
    private String[] list2;


    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        binding = ActivityShowListBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());

        setSupportActionBar(binding.toolbar);
        setupTop();
        setupRecycler();

        binding.fab.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {

            }
        });
    }

    private void setupRecycler() {
        RecyclerView recyclerView = findViewById(R.id.recycler_view_list);
        recyclerView.setLayoutManager(new LinearLayoutManager(this));
        int length = task.getLearnedList().length;
        int[] list1 = new int[length];
        String[] list2 = new String[length];
        setupArrayLists(task, list1, list2);
        adapter = new MyRecyclerViewAdapterList(this, list1, list2);
        adapter.setClickListener(this);
        recyclerView.setAdapter(adapter);
    }



    private void setupArrayLists(Task task, int[] list1, String[] list2) {
        for (int i = 0; i < list1.length; i++) {
            list1[i] = (i + task.getOffset());
            if (task.getLearnedList()[i] != 0){
                list2[i] = ("Done");
            } else {
                list2[i] = ("Not Done");
            }
        }
    }

    private void setupTop() {
        setName();
        setPercent();
        setProgressBar();
        setFraction();
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


    @Override
    public void onItemClick(View view, int position) {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        boolean finished = false;
        if (list2[position].equals("Done")) {
            finished = true;
        }
        String message = "Set this as finished: ";
        if (finished) {
            message = "Set this as unfinished: ";
        }
        builder.setMessage(message)
                .setTitle("Refresh: ");
        builder.setPositiveButton("Yes", new DialogInterface.OnClickListener() {
            public void onClick(DialogInterface dialog, int id) {
                task.getLearnedList()[position - task.getOffset()] = position - task.getOffset();
                setupRecycler();
                SharedPreferences sharedPreferences = getSharedPreferences("Tasks", MODE_PRIVATE);
                SharedPreferences.Editor prefsEditor = sharedPreferences.edit();
                Methods.saveToSharedPreferences(prefsEditor);
            }
        });
    }
}