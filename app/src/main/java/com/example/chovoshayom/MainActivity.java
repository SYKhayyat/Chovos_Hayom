package com.example.chovoshayom;

import android.os.Bundle;

import com.google.android.material.snackbar.Snackbar;

import androidx.appcompat.app.AppCompatActivity;

import android.util.Log;
import android.view.View;

import androidx.recyclerview.widget.GridLayoutManager;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.example.chovoshayom.databinding.ActivityMainBinding;

import android.view.Menu;
import android.view.MenuItem;

public class MainActivity extends AppCompatActivity  implements MyRecyclerViewAdapter.ItemClickListener{

    private ActivityMainBinding binding;
    private RecyclerView recyclerView;

    private RecyclerView.LayoutManager layoutManager;
    MyRecyclerViewAdapter adapter;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        // data to populate the RecyclerView with
        String[] tasks = {
                "Tanach",
                "Mishnayos",
                "Shas",
                "Yerushalmi",
                "Rambam",
                "Tur",
                "Shulchan Aruch",
                "Mishna Berurah"
        };
        int[] images = {R.drawable.android_tanach,
                R.drawable.android_mishnayos,
                R.drawable.android_shas,
                R.drawable.android_yerushalmi,
                R.drawable.android_rambam,
                R.drawable.android_tur,
                R.drawable.android_shulchan_aruch,
                R.drawable.android_mishna_berurah};
        // set up the RecyclerView
        RecyclerView recyclerView = findViewById(R.id.recycler_view);
        int numberOfColumns = 2;
        recyclerView.setLayoutManager(new GridLayoutManager(this, numberOfColumns));
        adapter = new MyRecyclerViewAdapter(this, tasks, images);
        adapter.setClickListener(this);
        recyclerView.setAdapter(adapter);
    }

    @Override
    public void onItemClick(View view, String task) {
        Log.i("TAG",task);
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.menu_main, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        // Handle action bar item clicks here. The action bar will
        // automatically handle clicks on the Home/Up button, so long
        // as you specify a parent activity in AndroidManifest.xml.
        int id = item.getItemId();

        //noinspection SimplifiableIfStatement
        if (id == R.id.action_settings) {
            return true;
        }

        return super.onOptionsItemSelected(item);
    }

}