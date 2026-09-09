package local.thor.wifiresume.tests;
import android.app.*;
import android.os.*;
import android.content.*;
import android.view.*;
import android.widget.*;
import java.util.*;
import java.lang.reflect.*;

/** Device UI integration: temporary fake entry only, no forget/reboot. */
public class UiTestRunner extends Instrumentation {
    private Activity activity;
    private final String temp="THOR_UI_TEST_ONLY", edited="THOR_UI_TEST_EDITED";
    public void onCreate(Bundle args){super.onCreate(args);start();}
    private List<View> roots() throws Exception {
        Class<?> wm=Class.forName("android.view.WindowManagerGlobal");
        Object instance=wm.getMethod("getInstance").invoke(null);
        Field views=wm.getDeclaredField("mViews");views.setAccessible(true);
        return new ArrayList<>((List<View>)views.get(instance));
    }
    private void visit(View v,List<View> all){all.add(v);if(v instanceof ViewGroup)for(int i=0;i<((ViewGroup)v).getChildCount();i++)visit(((ViewGroup)v).getChildAt(i),all);}
    private List<View> all() throws Exception {List<View> all=new ArrayList<>();for(View r:roots())visit(r,all);return all;}
    private void click(String text) throws Exception {
        final Throwable[] failure={null};runOnMainSync(()->{try{
            List<View> views=all();Collections.reverse(views);
            for(View v:views)if(v instanceof TextView&&text.contentEquals(((TextView)v).getText())&&v.isShown()&&v.isEnabled()&&v.isClickable()){v.performClick();return;}
            throw new AssertionError("Button missing: "+text);
        }catch(Throwable e){failure[0]=e;}});if(failure[0]!=null)throw new Exception(failure[0]);waitForIdleSync();
    }
    private void type(String ssid,String pwd) throws Exception {
        final Throwable[] failure={null};runOnMainSync(()->{try{List<EditText> fields=new ArrayList<>();for(View v:all())if(v instanceof EditText&&v.isShown())fields.add((EditText)v);if(fields.size()!=2)throw new AssertionError("Expected 2 fields");fields.get(0).setText(ssid);fields.get(1).setText(pwd);}catch(Throwable e){failure[0]=e;}});if(failure[0]!=null)throw new Exception(failure[0]);
    }
    private boolean contains(String value) throws Exception {final boolean[] yes={false};runOnMainSync(()->{try{for(View v:all())if(v instanceof TextView&&value.contentEquals(((TextView)v).getText())&&v.isShown())yes[0]=true;}catch(Exception e){throw new RuntimeException(e);}});return yes[0];}
    private void await(String text,boolean present) throws Exception{for(int i=0;i<60;i++){if(contains(text)==present){Thread.sleep(700);return;}Thread.sleep(250);}throw new AssertionError("UI condition timed out: "+text);}
    private void select(String ssid) throws Exception {final Throwable[] failure={null};runOnMainSync(()->{try{for(View v:all())if(v.getContentDescription()!=null&&("Sélectionner "+ssid).contentEquals(v.getContentDescription())){v.performClick();return;}throw new AssertionError("Missing radio");}catch(Throwable t){failure[0]=t;}});if(failure[0]!=null)throw new Exception(failure[0]);}
    private void modify(String ssid) throws Exception {final Throwable[] failure={null};runOnMainSync(()->{try{for(View v:all())if(v instanceof TextView&&ssid.contentEquals(((TextView)v).getText())){View card=(View)v.getParent().getParent();List<View> local=new ArrayList<>();visit(card,local);for(View b:local)if(b instanceof Button&&"Modifier".contentEquals(((Button)b).getText())){b.performClick();return;}}throw new AssertionError("Missing edit");}catch(Throwable t){failure[0]=t;}});if(failure[0]!=null)throw new Exception(failure[0]);}
    public void onStart(){Bundle report=new Bundle();try{
        activity=startActivitySync(new Intent().setClassName("local.thor.wifiresume","local.thor.wifiresume.MainActivity").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        Thread.sleep(2000);waitForIdleSync(); for(String leftover:new String[]{temp,edited})if(contains(leftover)){modify(leftover);click("Supprimer");click("Supprimer");await(leftover,false);}
        Field f=activity.getClass().getDeclaredField("networks");f.setAccessible(true);List<?> initial=(List<?>)f.get(activity);int before=initial.size();
        String original=before>0?(String)initial.get(0).getClass().getField("ssid").get(initial.get(0)):"";
        click("+ Ajouter");type(temp,"OnlySynthetic123!");click("Enregistrer");await(temp,true);
        select(temp);await("Pour : "+temp,true);
        modify(temp);type(edited,"OtherSynthetic456!");click("Enregistrer");await(edited,true);await(temp,false);
        modify(edited);click("Supprimer");click("Supprimer");await(edited,false);
        if(((List<?>)f.get(activity)).size()!=before)throw new AssertionError("Catalog count changed");
        if(!original.isEmpty()){select(original);await("Pour : "+original,true);}
        click("Connus d’Android");click("Fermer");
        report.putString("stream","PASS: actual UI add, select, edit, delete; original catalog count restored; Android-known picker opened. No connection or reboot triggered.\n");finish(Activity.RESULT_OK,report);
    }catch(Throwable t){report.putString("stream","FAIL: "+t.getClass().getSimpleName()+": "+t.getMessage()+"\n");finish(Activity.RESULT_CANCELED,report);}}
}
