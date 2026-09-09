package local.thor.wifiresume;

import android.app.*;
import android.os.*;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.content.*;
import android.text.InputType;
import android.text.method.PasswordTransformationMethod;
import android.view.*;
import android.widget.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.*;
import java.util.concurrent.*;

public final class MainActivity extends Activity {
    private static final int BG=0xff101e31, PANEL=0xff1a2b43, INK=0xfff0f5ff, MUTED=0xffb3c3da, BLUE=0xffa4c8ff, LINE=0xff354e70;
    private final ExecutorService io=Executors.newSingleThreadExecutor();
    private final Handler handler=new Handler(Looper.getMainLooper());
    private final ArrayList<NetworkStore.Network> networks=new ArrayList<>();
    private List<String> known=new ArrayList<>();
    private LinearLayout list;
    private TextView status, detail, chosen;
    private Button connect, repair, add, androidKnown, refresh;
    private ProgressBar progress;
    private File exchange;
    private String selected="", wifi="", workflow="", connectedSsid="";
    private boolean busy=false, ready=false, catalogValid=false, foreground=false;
    private long pollUntil=0;
    private boolean snapshotRunning=false;
    private String lastRenderedCatalog="";
    private boolean demo=false;
    private String language="fr";
    private String tr(String text){return I18n.text(this,text);}
    private void configureLanguage(String code){
        language="en".equals(code)?"en":"fr";
        android.content.res.Configuration c=new android.content.res.Configuration(getResources().getConfiguration());
        c.setLocale(new Locale(language));getResources().updateConfiguration(c,getResources().getDisplayMetrics());
    }
    private void chooseLanguage(){
        new AlertDialog.Builder(this).setTitle("Language / Langue").setSingleChoiceItems(new String[]{"Français","English"},"en".equals(language)?1:0,(d,which)->{
            getPreferences(0).edit().putString("language",which==1?"en":"fr").apply();d.dismiss();
            if(demo)getIntent().putExtra("language",which==1?"en":"fr");recreate();
        }).setNegativeButton(tr("Annuler"),null).show();
    }
    private void languageControl(LinearLayout parent){
        Button b=button("FR / EN",false);b.setOnClickListener(v->chooseLanguage());
        LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(dp(88),dp(44));lp.setMargins(dp(10),0,0,0);parent.addView(b,lp);
    }
    private void showHelp(){
        new AlertDialog.Builder(this).setTitle(tr("À quoi sert Thor Wi-Fi ?"))
            .setMessage(tr("ABOUT_BODY"))
            .setPositiveButton(tr("Compris"),null).show();
    }

    @Override public void onCreate(Bundle saved) {
        super.onCreate(saved);
        demo=getIntent().getBooleanExtra("demo",false);
        configureLanguage(demo?getIntent().getStringExtra("language"):getPreferences(0).getString("language",Locale.getDefault().getLanguage()));
        getWindow().setStatusBarColor(BG); getWindow().setNavigationBarColor(BG);
        // Prevent passwords in Recents thumbnails and screenshots of editor dialogs.
        selected=getPreferences(0).getString("selected", "");
        exchange=new File(getFilesDir(),"exchange"); exchange.mkdirs();
        build();
        if(demo){
            networks.add(new NetworkStore.Network("Home Wi-Fi","SampleOnly123"));networks.add(new NetworkStore.Network("Travel hotspot","SampleOnly456"));selected="Home Wi-Fi";
            connectedSsid="Home Wi-Fi";ready=true;catalogValid=true;status.setText(tr("Aperçu de démonstration"));detail.setText(tr("Réseaux fictifs · Aucune modification du Wi-Fi"));render();return;
        }
        runJob(tr("Préparation sur ce Thor…"), () -> {
            copyAssets("",new File(getFilesDir(),"bootstrap"));
            String r=ThorBridge.execute("bootstrap");
            if(!r.contains("INSTALL_OK") && !r.contains("BUSY")) throw new IOException(tr("Accès root AYN indisponible sur cet appareil."));
            return snapshot();
        }, this::apply);
    }
    @Override protected void onResume(){super.onResume();foreground=true;if(ready&&!busy&&!demo)refreshQuiet();}
    @Override protected void onPause(){super.onPause();foreground=false;handler.removeCallbacks(poll);}
    @Override protected void onDestroy(){super.onDestroy();handler.removeCallbacksAndMessages(null);io.shutdown();}
    private int dp(float n){return Math.round(n*getResources().getDisplayMetrics().density);}
    private GradientDrawable bg(int color,int border){GradientDrawable d=new GradientDrawable();d.setColor(color);d.setCornerRadius(dp(18));if(border!=0)d.setStroke(dp(1),border);return d;}
    private TextView label(String s,int size,int color){TextView v=new TextView(this);v.setText(s);v.setTextSize(size);v.setTextColor(color);v.setFontFeatureSettings("kern");return v;}
    private void gap(LinearLayout p,int h){View v=new View(this);p.addView(v,new LinearLayout.LayoutParams(1,dp(h)));}
    private LinearLayout column(){LinearLayout v=new LinearLayout(this);v.setOrientation(LinearLayout.VERTICAL);return v;}
    private LinearLayout row(){LinearLayout v=new LinearLayout(this);v.setOrientation(LinearLayout.HORIZONTAL);v.setGravity(Gravity.CENTER_VERTICAL);return v;}
    private Button button(String title,boolean primary){Button b=new Button(this);b.setText(title);b.setTextSize(14);b.setAllCaps(false);b.setTextColor(primary?BG:INK);b.setBackground(bg(primary?BLUE:PANEL,primary?0:LINE));b.setPadding(dp(12),0,dp(12),0);b.setMinHeight(dp(48));return b;}
    private void wide(LinearLayout p,View v){p.addView(v,new LinearLayout.LayoutParams(-1,dp(50)));}
    private void build(){
        if(getResources().getConfiguration().screenWidthDp>=600){buildWide();return;}
        ScrollView scroll=new ScrollView(this);scroll.setFillViewport(true);scroll.setBackgroundColor(BG);
        LinearLayout outer=column();outer.setPadding(dp(22),dp(20),dp(22),dp(26));scroll.addView(outer);
        TextView eyebrow=label(tr("AYN THOR  /  CONNEXION"),11,BLUE);eyebrow.setLetterSpacing(.16f);outer.addView(eyebrow);gap(outer,6);
        TextView title=label("Thor Wi-Fi",32,INK);title.setTypeface(Typeface.create("sans-serif-medium",0));LinearLayout titleRow=row();titleRow.addView(title,new LinearLayout.LayoutParams(0,-2,1));languageControl(titleRow);outer.addView(titleRow);gap(outer,16);
        LinearLayout panel=column();panel.setPadding(dp(17),dp(16),dp(17),dp(16));panel.setBackground(bg(PANEL,0));
        status=label(tr("Vérification…"),20,INK);status.setTypeface(Typeface.create("sans-serif-medium",0));panel.addView(status);gap(panel,6);
        detail=label(tr("Tes réseaux restent sur ton Thor."),13,MUTED);panel.addView(detail);gap(panel,12);
        // The only visual motif is the three real stages of the recovery cycle.
        TextView flow=label(tr("OUBLI    ›    REDÉMARRAGE    ›    CONNEXION"),10,BLUE);flow.setLetterSpacing(.05f);panel.addView(flow);outer.addView(panel);
        progress=new ProgressBar(this,null,android.R.attr.progressBarStyleHorizontal);progress.setIndeterminate(true);progress.setVisibility(View.INVISIBLE);outer.addView(progress,new LinearLayout.LayoutParams(-1,dp(5)));gap(outer,12);
        LinearLayout section=row();TextView heading=label(tr("Mes réseaux"),22,INK);heading.setTypeface(Typeface.create("sans-serif-medium",0));section.addView(heading,new LinearLayout.LayoutParams(0,-2,1));
        refresh=button(tr("Actualiser"),false);refresh.setOnClickListener(v->refresh());section.addView(refresh,new LinearLayout.LayoutParams(dp(112),dp(44)));outer.addView(section);gap(outer,12);
        list=column();outer.addView(list);
        LinearLayout actions=row();add=button(tr("+ Ajouter"),false);androidKnown=button(tr("Connus d’Android"),false);
        LinearLayout.LayoutParams half=new LinearLayout.LayoutParams(0,dp(48),1);half.setMargins(0,0,dp(8),0);actions.addView(add,half);actions.addView(androidKnown,new LinearLayout.LayoutParams(0,dp(48),1));outer.addView(actions);
        add.setOnClickListener(v->editor(null,""));androidKnown.setOnClickListener(v->pickKnown());gap(outer,20);
        chosen=label(tr("Choisis un réseau pour continuer."),14,MUTED);outer.addView(chosen);gap(outer,10);
        connect=button(tr("Se connecter"),true);connect.setOnClickListener(v->perform(false));wide(outer,connect);gap(outer,10);
        repair=button(tr("Oublier, redémarrer et reconnecter"),false);repair.setOnClickListener(v->perform(true));wide(outer,repair);gap(outer,16);
        TextView help=label(tr("Sans PC · La reprise se fait après le redémarrage.\nSi demandé, déverrouille le Thor."),12,MUTED);outer.addView(help);gap(outer,12);
        Button about=button(tr("Fichier Wi-Fi et aide"),false);about.setOnClickListener(v->showHelp());wide(outer,about);
        setContentView(scroll);render();
    }
    private void buildWide(){
        LinearLayout outer=column();outer.setBackgroundColor(BG);outer.setPadding(dp(24),dp(12),dp(24),dp(16));
        LinearLayout header=row();LinearLayout brand=column();TextView eyebrow=label(tr("AYN THOR  /  CONNEXION"),10,BLUE);eyebrow.setLetterSpacing(.14f);brand.addView(eyebrow);
        TextView title=label("Thor Wi-Fi",28,INK);title.setTypeface(Typeface.create("sans-serif-medium",0));brand.addView(title);header.addView(brand,new LinearLayout.LayoutParams(0,-2,1));
        refresh=button(tr("Actualiser"),false);refresh.setOnClickListener(v->refresh());header.addView(refresh,new LinearLayout.LayoutParams(dp(110),dp(44)));languageControl(header);outer.addView(header);gap(outer,12);
        progress=new ProgressBar(this,null,android.R.attr.progressBarStyleHorizontal);progress.setIndeterminate(true);progress.setVisibility(View.INVISIBLE);outer.addView(progress,new LinearLayout.LayoutParams(-1,dp(3)));
        LinearLayout body=row();body.setGravity(Gravity.TOP);outer.addView(body,new LinearLayout.LayoutParams(-1,0,1));
        LinearLayout left=column();LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(0,-1,1);lp.setMargins(0,0,dp(22),0);body.addView(left,lp);
        TextView section=label(tr("Mes réseaux"),20,INK);section.setTypeface(Typeface.create("sans-serif-medium",0));left.addView(section);gap(left,10);
        ScrollView networkScroll=new ScrollView(this);list=column();networkScroll.addView(list);left.addView(networkScroll,new LinearLayout.LayoutParams(-1,0,1));gap(left,8);
        LinearLayout tools=row();add=button(tr("+ Ajouter"),false);androidKnown=button(tr("Connus d’Android"),false);LinearLayout.LayoutParams h=new LinearLayout.LayoutParams(0,dp(46),1);h.setMargins(0,0,dp(8),0);tools.addView(add,h);tools.addView(androidKnown,new LinearLayout.LayoutParams(0,dp(46),1));left.addView(tools);
        add.setOnClickListener(v->editor(null,""));androidKnown.setOnClickListener(v->pickKnown());
        ScrollView rightScroll=new ScrollView(this);LinearLayout right=column();rightScroll.addView(right);body.addView(rightScroll,new LinearLayout.LayoutParams(0,-1,1));
        LinearLayout panel=column();panel.setPadding(dp(16),dp(14),dp(16),dp(14));panel.setBackground(bg(PANEL,0));status=label(tr("Vérification…"),18,INK);status.setTypeface(Typeface.create("sans-serif-medium",0));panel.addView(status);gap(panel,5);detail=label(tr("Tes réseaux restent sur ton Thor."),12,MUTED);panel.addView(detail);gap(panel,10);panel.addView(label(tr("OUBLI   ›   REDÉMARRAGE   ›   CONNEXION"),10,BLUE));right.addView(panel);gap(right,14);
        chosen=label(tr("Choisis un réseau pour continuer."),13,MUTED);right.addView(chosen);gap(right,8);
        connect=button(tr("Se connecter"),true);connect.setOnClickListener(v->perform(false));wide(right,connect);gap(right,8);
        repair=button(tr("Oublier, redémarrer et reconnecter"),false);repair.setOnClickListener(v->perform(true));wide(right,repair);gap(right,10);
        TextView help=label(tr("Sans PC · Déverrouille le Thor après reboot si demandé."),11,MUTED);right.addView(help);gap(right,8);
        TextView about=label(tr("Fichier Wi-Fi et aide  →"),13,BLUE);about.setPadding(0,dp(8),0,dp(8));about.setOnClickListener(v->showHelp());right.addView(about);
        setContentView(outer);render();
    }
    private NetworkStore.Network selection(){for(NetworkStore.Network n:networks)if(n.ssid.equals(selected))return n;return null;}
    private void render(){
        list.removeAllViews();
        if(networks.isEmpty()){TextView empty=label(tr("Ajoute ton premier réseau, ou choisis un réseau connu d’Android."),15,MUTED);empty.setPadding(0,dp(8),0,dp(20));list.addView(empty);}
        for(NetworkStore.Network n:networks){
            boolean active=n.ssid.equals(selected);LinearLayout card=column();card.setPadding(dp(14),dp(13),dp(14),dp(12));card.setBackground(bg(active?0xff263d5d:PANEL,active?BLUE:0));
            LinearLayout top=row();RadioButton radio=new RadioButton(this);radio.setChecked(active);radio.setContentDescription(tr("Sélectionner ")+n.ssid);radio.setButtonTintList(android.content.res.ColorStateList.valueOf(BLUE));
            View.OnClickListener select=v->{if(!busy){selected=n.ssid;getPreferences(0).edit().putString("selected",selected).apply();render();}};
            radio.setOnClickListener(select);top.addView(radio,new LinearLayout.LayoutParams(dp(42),dp(42)));
            TextView name=label(n.ssid,18,INK);name.setTypeface(Typeface.create("sans-serif-medium",0));top.addView(name,new LinearLayout.LayoutParams(0,-2,1));top.setOnClickListener(select);card.addView(top);
            LinearLayout lower=row();TextView hint=label(n.ssid.equals(connectedSsid)?tr("Connecté ✓"):(active?tr("Réseau sélectionné · WPA2"):tr("WPA2 · mot de passe enregistré")),11,n.ssid.equals(connectedSsid)?0xff9be5bd:MUTED);lower.addView(hint,new LinearLayout.LayoutParams(0,-2,1));
            Button edit=button(tr("Modifier"),false);edit.setEnabled(!busy&&!demo);edit.setOnClickListener(v->editor(n,n.ssid));lower.addView(edit,new LinearLayout.LayoutParams(dp(86),dp(44)));card.addView(lower);
            list.addView(card,new LinearLayout.LayoutParams(-1,-2));gap(list,10);
        }
        NetworkStore.Network n=selection();chosen.setText(n==null?tr("Choisis un réseau pour continuer."):tr("Pour : ")+n.ssid);
        connect.setText(n!=null&&n.ssid.equals(connectedSsid)?tr("Connecté ✓"):tr("Se connecter"));
        connect.setEnabled(ready&&catalogValid&&!busy&&!demo&&n!=null&&!n.ssid.equals(connectedSsid));repair.setEnabled(ready&&catalogValid&&!busy&&!demo&&n!=null);add.setEnabled(ready&&catalogValid&&!busy&&!demo);androidKnown.setEnabled(ready&&catalogValid&&!busy&&!demo);refresh.setEnabled(ready&&!busy&&!demo);
        progress.setVisibility(busy?View.VISIBLE:View.INVISIBLE);
    }
    private EditText field(String value,String hint,boolean password){EditText e=new EditText(this);e.setSingleLine(true);e.setTextColor(INK);e.setHintTextColor(MUTED);e.setTextSize(16);e.setHint(hint);e.setInputType(password?InputType.TYPE_CLASS_TEXT|InputType.TYPE_TEXT_VARIATION_PASSWORD:InputType.TYPE_CLASS_TEXT|InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS);e.setText(value);e.setImportantForAutofill(View.IMPORTANT_FOR_AUTOFILL_NO);return e;}
    private void editor(NetworkStore.Network existing,String initial){
        LinearLayout form=column();form.setPadding(dp(22),dp(8),dp(22),0);
        form.addView(label(tr("Nom du réseau (SSID)"),12,MUTED));EditText ssid=field(initial,tr("Nom exact du réseau"),false);form.addView(ssid);gap(form,12);
        form.addView(label(tr("Mot de passe WPA2"),12,MUTED));EditText password=field(existing==null?"":existing.password,tr("8 à 63 caractères"),true);form.addView(password);
        CheckBox show=new CheckBox(this);show.setText(tr("Afficher le mot de passe"));show.setTextColor(MUTED);show.setOnCheckedChangeListener((b,checked)->{password.setTransformationMethod(checked?null:PasswordTransformationMethod.getInstance());password.setSelection(password.length());});form.addView(show);
        TextView error=label("",12,0xffffb6bb);form.addView(error);
        AlertDialog.Builder builder=new AlertDialog.Builder(this).setTitle(existing==null?tr("Ajouter un réseau"):tr("Modifier le réseau")).setView(form).setPositiveButton(tr("Enregistrer"),null).setNegativeButton(tr("Annuler"),null);
        if(existing!=null)builder.setNeutralButton(tr("Supprimer"),null);
        AlertDialog dialog=builder.create();dialog.getWindow();dialog.setOnShowListener(d->{
            dialog.getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
            dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(v->{
                try{
                    NetworkStore.Network edited=new NetworkStore.Network(ssid.getText().toString(),password.getText().toString());
                    ArrayList<NetworkStore.Network> next=new ArrayList<>(networks);if(existing==null)next.add(edited);else next.set(next.indexOf(existing),edited);NetworkStore.format(next);
                    save(next,edited.ssid,dialog);
                }catch(IllegalArgumentException ex){error.setText(tr(ex.getMessage()));}
            });
            if(existing!=null)dialog.getButton(AlertDialog.BUTTON_NEUTRAL).setOnClickListener(v->new AlertDialog.Builder(this).setTitle(tr("Retirer ce réseau de la liste ?")).setMessage(existing.ssid+tr(" sera retiré de l’application et du fichier Wi-Fi. Le réseau enregistré dans Android est conservé."))
                .setNegativeButton(tr("Annuler"),null).setPositiveButton(tr("Supprimer"),(x,y)->{ArrayList<NetworkStore.Network> next=new ArrayList<>(networks);next.remove(existing);save(next,"",dialog);}).show());
        });dialog.show();
    }
    private void save(List<NetworkStore.Network> next,String prefer,AlertDialog dialog){
        final String serialized=NetworkStore.format(next);dialog.dismiss();
        runJob(tr("Enregistrement…"),()->{write("catalog-request.txt",serialized);String r=ThorBridge.execute("save");if(!r.contains("SAVE_OK"))throw new IOException(explain(r));return snapshot();},s->{selected=prefer;apply(s);Toast.makeText(this,tr("Liste enregistrée"),Toast.LENGTH_SHORT).show();});
    }
    private void pickKnown(){
        if(known.isEmpty()){new AlertDialog.Builder(this).setTitle(tr("Aucun réseau enregistré détecté")).setMessage(tr("Ajoute un réseau avec son SSID et son mot de passe, ou actualise la liste.")).setPositiveButton(tr("Compris"),null).show();return;}
        new AlertDialog.Builder(this).setTitle(tr("Réseaux enregistrés dans Android")).setItems(known.toArray(new String[0]),(d,i)->{
            String name=known.get(i);for(NetworkStore.Network n:networks)if(n.ssid.equals(name)){selected=name;render();return;}editor(null,name);
        }).setNegativeButton(tr("Fermer"),null).show();
    }
    private void perform(boolean reboot){
        NetworkStore.Network n=selection();if(n==null||busy)return;
        if(reboot){new AlertDialog.Builder(this).setTitle(tr("Redémarrer pour ce réseau ?")).setMessage(tr("Le Thor va oublier uniquement « ")+n.ssid+tr(" », redémarrer, puis s’y reconnecter avec le mot de passe enregistré.\n\nLes autres réseaux Android sont conservés. Déverrouille l’écran après le reboot si demandé."))
            .setNegativeButton(tr("Annuler"),null).setPositiveButton(tr("Oublier et redémarrer"),(d,w)->start(n,true)).show();}
        else start(n,false);
    }
    private void start(NetworkStore.Network n,boolean reboot){
        runJob(reboot?tr("Préparation du redémarrage…"):tr("Connexion à ")+n.ssid+"…",()->{
            write("selection-request.txt",NetworkStore.format(Collections.singletonList(n)));
            String r=ThorBridge.execute(reboot?"forget":"connect");
            if(!r.contains(reboot?"REBOOT_REQUESTED":"CONNECT_STARTED"))throw new IOException(explain(r));
            return r;
        },r->{pollUntil=System.currentTimeMillis()+180000;status.setText(reboot?tr("Redémarrage demandé"):tr("Connexion en cours…"));detail.setText(reboot?tr("La reprise sera automatique après le démarrage."):tr("Vérification du réseau sélectionné et de son adresse IP."));handler.postDelayed(poll,3000);});
    }
    private final Runnable poll=new Runnable(){public void run(){if(foreground&&!demo){if(!busy)refreshQuiet();else handler.postDelayed(this,3000);}}};
    private void refresh(){runJob(tr("Actualisation…"),this::snapshot,this::apply);}
    // Poll only while recovery is active. Never disable buttons or rebuild an
    // unchanged network list merely to update the connection status.
    private void refreshQuiet(){
        if(busy||snapshotRunning||demo)return;
        snapshotRunning=true;
        io.execute(()->{try{Snapshot s=snapshot();handler.post(()->{snapshotRunning=false;if(!isDestroyed()&&!busy)apply(s);});}
            catch(Exception e){handler.post(()->{snapshotRunning=false;if(!isDestroyed()&&!busy){status.setText(tr("Action non terminée"));detail.setText(tr("Actualise pour vérifier la connexion."));}});}});
    }
    private static final class Snapshot{String catalog,known,wifi,status;}
    private Snapshot snapshot() throws Exception {
        String r=ThorBridge.execute("snapshot");if(!r.contains("SNAPSHOT_OK"))throw new IOException(explain(r));
        Snapshot s=new Snapshot();s.catalog=read("catalog.txt");s.known=read("known.txt");s.wifi=read("wifi.txt");s.status=read("status.txt");return s;
    }
    private void apply(Snapshot s){
        String previousConnected=connectedSsid, previousSelected=selected;
        boolean redraw=!s.catalog.equals(lastRenderedCatalog);
        try{List<NetworkStore.Network> incoming=NetworkStore.parse(s.catalog);if(redraw){networks.clear();networks.addAll(incoming);}known=NetworkStore.known(s.known);wifi=s.wifi;workflow=s.status;ready=true;catalogValid=true;
            if(selection()==null)selected=networks.isEmpty()?"":networks.get(0).ssid;getPreferences(0).edit().putString("selected",selected).apply();
            connectedSsid=WifiState.connectedSsid(wifi);
            String connected=connectedSsid;
            if(workflow.contains("RESUME_PENDING=1")){status.setText(tr("Reprise prévue au redémarrage"));detail.setText(tr("La demande de reconnexion est enregistrée."));}
            else if(workflow.contains("RECONNECTING")){status.setText(tr("Connexion en cours…"));detail.setText(tr("Vérification de l’association et de l’adresse IP."));pollUntil=System.currentTimeMillis()+180000;}
            else if(!connected.isEmpty()){status.setText(tr("Connecté à ")+connected);detail.setText(String.format(tr("Wi-Fi actif · %d réseau(x) dans ta liste"),networks.size()));pollUntil=0;}
            else{status.setText(wifi.contains("Wifi is disabled")?tr("Wi-Fi désactivé"):tr("Aucune connexion Wi-Fi"));detail.setText(workflow.contains("RECONNECT_NOT_CONFIRMED")?tr("Connexion non confirmée. Vérifie le mot de passe et la portée du réseau."):tr("Choisis un réseau ci-dessous pour te connecter."));}
            if(workflow.contains("WORKER_INTERRUPTED")) {
                status.setText(tr("Opération interrompue"));
                detail.setText(tr("La tentative précédente s’est arrêtée. Tu peux relancer la connexion ou la récupération."));
            }
            if(!selected.equals(connectedSsid) && workflow.contains("RECONNECT_NOT_CONFIRMED")) {
                if(workflow.contains("NETWORK_NOT_VISIBLE")) detail.setText(tr("Réseau non détecté. Vérifie sa portée et relance la connexion."));
                else if(workflow.contains("WPA3_UNSUPPORTED")||workflow.contains("SECURITY_UNSUPPORTED")) detail.setText(tr("Sécurité Wi-Fi non prise en charge par ce firmware."));
                else detail.setText(tr("Connexion au réseau choisi non confirmée. Vérifie le mot de passe et la portée."));
            }
        }catch(IllegalArgumentException e){status.setText(tr("Fichier Wi-Fi à corriger"));detail.setText(tr(e.getMessage()));ready=true;catalogValid=false;}
        if(redraw||!previousConnected.equals(connectedSsid)||!previousSelected.equals(selected)||!catalogValid)render();
        lastRenderedCatalog=s.catalog;
        handler.removeCallbacks(poll);
        if(foreground&&!demo&&(workflow.contains("RECONNECTING")||workflow.contains("RESUME_PENDING=1")))handler.postDelayed(poll,4000);
    }
    private String explain(String result){
        if(result.contains("SECURITY_UNKNOWN"))return tr("Sécurité inconnue : ouvre les paramètres Wi-Fi pour détecter ce réseau, puis réessaie. Aucun réseau oublié.");
        if(result.contains("BUSY")||result.contains("ALREADY_PENDING"))return tr("Une opération Wi-Fi est déjà en cours. Attends sa fin puis actualise.");
        if(result.contains("NO_MATCHING"))return tr("Ce réseau n’est pas enregistré dans Android. Utilise d’abord Se connecter.");
        if(result.contains("UNSUPPORTED"))return tr("Ce firmware n’expose pas les commandes Wi-Fi nécessaires.");
        if(result.contains("INVALID"))return tr("Vérifie le SSID et le mot de passe enregistrés.");
        if(result.contains("FORGET")||result.contains("NO_REBOOT"))return tr("L’oubli du réseau n’a pas été confirmé. Aucun redémarrage demandé.");
        return tr("L’opération AYN n’a pas été confirmée. Actualise et vérifie l’accès root sur ce Thor.");
    }
    private interface Job<T>{T run() throws Exception;}
    private interface Done<T>{void accept(T result);}
    private <T> void runJob(String message,Job<T> task,Done<T> done){
        if(busy)return;busy=true;detail.setText(message);render();
        io.execute(()->{try{T r=task.run();handler.post(()->{if(isDestroyed())return;busy=false;done.accept(r);render();});}
            catch(Exception e){handler.post(()->{if(isDestroyed())return;busy=false;status.setText(tr("Action non terminée"));detail.setText(e instanceof IOException&&e.getMessage()!=null?tr(e.getMessage()):tr("Le service root AYN ne répond pas. Rouvre l’application pour réessayer."));if(!ready){ready=true;}render();});}});
    }
    private void write(String name,String content) throws IOException{Files.write(new File(exchange,name).toPath(),content.getBytes(StandardCharsets.UTF_8));}
    private String read(String name) throws IOException{return new String(Files.readAllBytes(new File(exchange,name).toPath()),StandardCharsets.UTF_8);}
    private void copyAssets(String asset,File target) throws IOException{
        String[] names=getAssets().list(asset);if(names!=null&&names.length>0){target.mkdirs();for(String name:names)copyAssets(asset.isEmpty()?name:asset+"/"+name,new File(target,name));}
        else{target.getParentFile().mkdirs();try(InputStream in=getAssets().open(asset);OutputStream out=new FileOutputStream(target)){byte[] b=new byte[8192];int c;while((c=in.read(b))!=-1)out.write(b,0,c);}}
    }
}
