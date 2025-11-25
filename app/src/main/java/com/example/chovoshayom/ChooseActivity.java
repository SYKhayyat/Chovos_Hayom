//package com.example.chovoshayom;
//
//import android.content.Intent;
//import android.os.Bundle;
//
//import com.google.android.material.snackbar.Snackbar;
//
//import androidx.appcompat.app.AppCompatActivity;
//
//import android.view.View;
//import android.widget.Button;
//
//import androidx.navigation.NavController;
//import androidx.navigation.Navigation;
//import androidx.navigation.ui.AppBarConfiguration;
//import androidx.navigation.ui.NavigationUI;
//
//import com.example.chovoshayom.databinding.ActivityChooseBinding;
//
//public class ChooseActivity extends AppCompatActivity {
//
//    private ActivityChooseBinding binding;
//
//    @Override
//    protected void onCreate(Bundle savedInstanceState) {
//        super.onCreate(savedInstanceState);
//
//        Intent myIntent = getIntent();
//
//        // Get the MyCustomObject from the intent's extras
//        Task task = (Task) myIntent.getSerializableExtra("taskObject");
//
//        binding = ActivityChooseBinding.inflate(getLayoutInflater());
//        setContentView(binding.getRoot());
//
//        setSupportActionBar(binding.toolbar);
//
//        binding.fab.setOnClickListener(new View.OnClickListener() {
//            @Override
//            public void onClick(View view) {
//                Snackbar.make(view, "Replace with your own action", Snackbar.LENGTH_LONG)
//                        .setAnchorView(R.id.fab)
//                        .setAction("Action", null).show();
//            }
//        });
//        if (task.getName().equals("Tanach") {
//            Button torah = new Button(this);
//            task = new Task("Torah", "Perek", 0);
//            torah.setText("Torah");
//            torah.setOnClickListener(new View.OnClickListener() {
//                @Override
//                public void onClick(View v) {
//                    Intent intent = new Intent(ChooseActivity.this, ChooseActivity.class);
//                    intent.putExtra("taskObject", task);
//                    startActivity(intent);
//                }
//            });        }
//            task.getName().equals("Mishnayos") ||
//            task.getName().equals("Shas")||
//            task.getName().equals("Yerushalmi")||
//            task.getName().equals("Rambam")||
//            task.getName().equals("Tur")||
//            task.getName().equals("Shulchan Aruch")||
//            task.getName().equals("Mishna Berura")){
//
//        }
//    }
//}