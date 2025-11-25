package com.example.chovoshayom;

import android.os.Bundle;

import com.google.android.material.snackbar.Snackbar;

import androidx.appcompat.app.AppCompatActivity;

import android.view.View;
import android.widget.ProgressBar;
import android.widget.TextView;

import com.example.chovoshayom.databinding.ActivityDashboardBinding;

public class DashboardActivity extends AppCompatActivity {

    private ActivityDashboardBinding binding;

    private Task task = getIntent().getParcelableExtra("taskObject");

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

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

        setPercentage();
        setProgressBar();
        setFraction();
        setupButton();
    }

    private void setPercentage() {
        TextView percent = (TextView) findViewById(R.id.percent);
        double percentFinished = task.getPercentage();
        String displayPercentage = percentFinished + "%";
        percent.setText(displayPercentage);
    }

    private void setProgressBar() {
        ProgressBar progressBar = findViewById(R.id.progressBar);
        progressBar.setMax((int) task.getTotal());
        progressBar.setProgress((int) task.getLearned());
    }

    private void setFraction() {
        TextView fraction = (TextView) findViewById(R.id.fraction);
        String getFraction = task.getLearned() + " / " + task.getTotal();
        fraction.setText(getFraction);
    }

    private void setupButton() {

    }

}