import java.io.BufferedReader;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.IOException;
import java.io.PrintStream;
import java.util.StringTokenizer;


public class IOParser {

	/**
	 * @param args
	 * @throws IOException 
	 */
	public static void main(String[] args) throws IOException {
	
		String fileinput = args[0];
		String fileinput_vmstat = args[1];
		String filename = args[2];
		
		//String fileinput ="/home/harold/starfish/profile_data/iostat_output-ip-10-204-186-12.ec2.internal";//distcp_all_local_iostat";
		//String fileinput_vmstat = "/home/harold/starfish/profile_data/distcp_all_local_vmstat";
		// TODO Auto-generated method stub
		//String filename = "/home/harold/starfish/profile_data/throughput_test_2_write_20GB_postprocessed";//distcp_all_local_postprocessed";
		
		//for(int i =0; i < 6; i++)
		//{
		/*File f;
		f=new File(filename);*/
		FileOutputStream fout = null;
		/*if(!f.exists()){
	    	  f.createNewFile();
	    }*/
		try {
			fout = new FileOutputStream (filename);
		} catch (FileNotFoundException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
		PrintStream ps = new PrintStream(fout);

		File finput = new File(fileinput);
		File finput_vmstat = new File(fileinput_vmstat);
		
		BufferedReader input =  new BufferedReader(new FileReader(finput));
		String line = null; //not declared within while loop
		ps.println("DISK IO");
		ps.println("MBRead/s MBWrite/s");
		while (( line = input.readLine()) != null){
			if(line.contains("sda2"))
			{
				StringTokenizer st = new StringTokenizer(line);
				st.nextToken();
				st.nextToken();
				String read = st.nextToken();
				String write = st.nextToken();
				ps.println(read+" "+write);
			}
			
		}
		
		input.close();
		
		input =  new BufferedReader(new FileReader(finput));
		ps.println("\n\n\n\n\nCPU");
		ps.println("%user %nice %system %iowait %steal %idle");
		while (( line = input.readLine()) != null){
			if(line.contains("avg-cpu"))
			{
				line = input.readLine();
				if(line != null)
				{
					//%user   %nice %system %iowait  %steal   %idle
					StringTokenizer st = new StringTokenizer(line);
					ps.println(st.nextToken()+" "+st.nextToken()+" "+st.nextToken()+" "+st.nextToken()+" "+st.nextToken()+" "+st.nextToken());
				}
			}
			
		}
		input.close();
		
		
		
		input =  new BufferedReader(new FileReader(finput_vmstat));
		ps.println("\n\n\n\n\nMemory");
		ps.println("swpd free buff cache");
		while (( line = input.readLine()) != null){
			if(!line.contains("sw"))
			{
				
				StringTokenizer st = new StringTokenizer(line);
				st.nextToken();
				st.nextToken();
				ps.println(st.nextToken()+" "+st.nextToken()+" "+st.nextToken()+" "+st.nextToken());
				
			}
			
		}
		input.close();
		
		fout.close();
		ps.flush();
		ps.close();
		//}
		
	}

}
