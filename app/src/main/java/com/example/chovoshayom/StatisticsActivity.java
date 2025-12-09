package com.example.chovoshayom;

import static com.example.chovoshayom.TasksSetup.set;
import static com.example.chovoshayom.TasksSetup.setupTotals;

import android.content.SharedPreferences;
import android.os.Bundle;
import android.util.Log;
import android.widget.TextView;

import androidx.activity.EdgeToEdge;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;

public class StatisticsActivity extends AppCompatActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_statistics);
        refreshStatistics();
        printStatistics();
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
        String names = "Names";
        String learneds = "Learned:";
        String totals = "Total:";
        String percents = "Percent:";
        for (Task t: set){
            names += "\n" + t.getName();
            learneds += "\n" + String.valueOf(t.getLearned());
            totals += "\n" + String.valueOf(t.getTotal());
            percents += "\n" + String.valueOf(t.getPercentage());
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
}