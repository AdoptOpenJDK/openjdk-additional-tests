/*******************************************************************************
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*      https://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*******************************************************************************/
package net.adoptopenjdk.casa.verbose_gc_parser;

import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;

import net.adoptopenjdk.casa.arg_parser.Arg;
import net.adoptopenjdk.casa.arg_parser.ArgException;
import net.adoptopenjdk.casa.arg_parser.ArgHandler;
import net.adoptopenjdk.casa.arg_parser.ArgParameterType;
import net.adoptopenjdk.casa.arg_parser.ArgParser;
import net.adoptopenjdk.casa.util.FileTailer;
import net.adoptopenjdk.casa.util.Utilities;
import net.adoptopenjdk.casa.xml_parser.Element;
import net.adoptopenjdk.casa.xml_parser.HierarchyException;
import net.adoptopenjdk.casa.xml_parser.ParseError;
import net.adoptopenjdk.casa.xml_parser.VoidElementHandler;
import net.adoptopenjdk.casa.xml_parser.XMLHierarchy;
import net.adoptopenjdk.casa.xml_parser.XMLParser;

/**
 * Verbose parser application which offers a variety of features for parsing verbose GC files. 
 * 
 *  
 *
 */
public class VerboseGCTailer 
{
	private static VerboseGCTailer tailerInstance; 

	/**
	 * 
	 * 
	 * @param args
	 */
	public static void main(String args[])
	{
		try 
		{
			tailerInstance = null; 
			
			// Handle VM shutdown. 
			Runtime.getRuntime().addShutdownHook
			(
				new Thread() 
				{
					public void run()
					{
						if (tailerInstance != null)
							tailerInstance.shutdown(); 
					}
				}
			);
			
			tailerInstance = new VerboseGCTailer(args);
		} 
		catch (IOException e) 
		{
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
	}
	
	// Options from the command line 
	private String filename;	

	// Poll period for the verbose file 
	private final double PERIOD_S = 0.1;
	
	// Keeps count of events in the file. 
	private VerboseUtil.VerboseEventCounter counter; 
	
	// 
	private Thread outputThread; 
	private Thread parseThread;
	private FileTailer tailer;
				
	private double startTime;
	private double lastEventTime; 
	
	private boolean updated; 
	
	/**
	 * Start tailing the file. Blocks until either shutdown is called or the final 
	 * closing tag is parsed. 
	 * 
	 * @param filename
	 * @throws IOException
	 */
	public VerboseGCTailer (String args[]) throws IOException
	{	
		// Parse the command line. 
		parseArgs(args); 
				
		tailer = null; 		
		updated = false; 				
		counter = new VerboseUtil.VerboseEventCounter(); 
				
		final XMLParser parser = getParser(); 
		
		// The parse thread parses the stream generated by the tailer.  
		parseThread = new Thread() 
		{
			public void run() 
			{				
				try 
				{
					tailer = new FileTailer(filename, PERIOD_S, Event.FATAL_ERROR);
					InputStream stream = tailer.getInputStream();
					parser.parse(stream, filename);																
				}
				catch (IOException e) 
				{
					Event.FATAL_ERROR.issue(e);
				}				
			}
		};									
		
		outputThread = new Thread() 
		{
			public void run() 
			{
				while (true) 
				{	
					if (Thread.interrupted())
						break; 
					
					try 
					{							
						if (updated)
						{
							synchronized (counter)
							{
								updated = false; 
																 							
								StringBuilder builder = new StringBuilder(); 
								
								builder.append("| " + Utilities.formatTime(lastEventTime - startTime));
								
								ArrayList<String> keys = counter.keySet(); 			
								
								for (String key : keys)
									builder.append(" | " + key + ": " + counter.get(key));
																							
								System.out.println("\n" + builder.toString());
							}
						}						
						Utilities.idle(PERIOD_S);
					} 
					catch (InterruptedException e) 
					{
						break; 
					}
					catch (Throwable e)
					{
						Event.FATAL_ERROR.issue(e); 
					}
				}
			}
		};

		parseThread.setDaemon(true);		
		outputThread.setDaemon(true);
		
		parseThread.start(); 
		outputThread.start(); 
		
		try { outputThread.join(); } 
		catch (InterruptedException e) { } 
		
		try { tailer.join();       } 
		catch (InterruptedException e) { }
		
		try { parseThread.join();  } 
		catch (InterruptedException e) { }
	}

	/**
	 * Parses the given command line arguments 
	 * 
	 * @param args
	 */
	private void parseArgs(String args[])
	{
		try 
		{
			ArgParser argParser = new ArgParser(true);
			
			Arg filenameArg = new Arg("Verbose file to tail ", true, new ArgParameterType[] {ArgParameterType.STRING}, 
				new ArgHandler()
				{			
					public void handle(Arg arg) throws ArgException 
					{				
						filename = arg.getParameterType(0).parse(arg.getParameter(0));							
					}
				}
			);
			
			argParser.addArg(filenameArg);
			
			argParser.parse(args);		
		} 		
		catch (ArgException e) 
		{			
			Event.BAD_ARGUMENTS.issue(e);	
		}	
	}	
	
	/**
	 * Stops tailing, allowing the contructor to return. 
	 */
	public void shutdown()
	{
		if (tailer != null)
			tailer.interrupt(); 
				
		if (parseThread != null)
			parseThread.interrupt();
				
		if (outputThread != null)
			outputThread.interrupt();			
	}
	
	/**
	 * Parses the verbose file as it is written into the local GCOps instance. This
	 * provides an ongoing record of the GC's activity as the workload is running. 
	 * 
	 * @param filename
	 * @throws IOException
	 */
	private XMLParser getParser() throws IOException
	{
		XMLHierarchy hierarchy = new XMLHierarchy("verbosegc");
		hierarchy.makePermissive("verbosegc");
																						
		final XMLParser parser = new XMLParser(hierarchy, Event.PARSE_ERROR);
		
		parser.setElementHandler("verbosegc", new VoidElementHandler() 
		{				
			public void elementEnd(Element element) throws HierarchyException, ParseError 
			{	
				synchronized (counter)
				{
					// Shutdown (stop tailing) once we read the closing tag of the file. 
					shutdown();
				}
			}
		});
		
		
		parser.setElementHandler("initialized", new VoidElementHandler() 
		{				
			public void elementEnd(Element element) throws HierarchyException, ParseError 
			{
				synchronized (counter)
				{
					// Record the start time from the initialized tag. 
					startTime = VerboseUtil.parseTimestamp(element.getAttribute("timestamp"), 0);
				}
			}
		});
		
		parser.setElementHandler("gc-start", new VoidElementHandler() 
		{				
			public void elementEnd(Element element) throws HierarchyException, ParseError 
			{		
				synchronized (counter)
				{
					// Record the timestamp of the gc-start tag as the last event time. 
					lastEventTime = VerboseUtil.parseTimestamp(element.getAttribute("timestamp"), 0);
					
					// Increment counters related to gc-start 
					VerboseUtil.countGCStart(element, counter);
										
					// Update the output for each global. 
					if (element.getAttribute("type").equals("global"))
						updated = true;
				}
			}
		});
		
		
		parser.setElementHandler("percolate-collect", new VoidElementHandler() 
		{				
			public void elementEnd(Element element) throws HierarchyException, ParseError 
			{		
				synchronized (counter)
				{
					// Record the time of this event as the last event time 
					lastEventTime = VerboseUtil.parseTimestamp(element.getAttribute("timestamp"), 0);	
					
					// Increment the percolate counter 
					counter.incrementAndGet(VerboseEvent.PERCOLATE_COLLECT.getSymbol()); 
					
					// Update the output for each percolate 
					updated = true; 					
				}
			}
		});

		
		parser.setElementHandler("gc-op", new VoidElementHandler() 
		{				
			public void elementEnd(Element element) throws HierarchyException, ParseError 
			{		
				synchronized (counter)
				{
					// Redord the gc-op timestamp as the last event time. 
					lastEventTime = VerboseUtil.parseTimestamp(element.getAttribute("timestamp"), 0);
					
					// Increment counters for gc-op related events. If any adverse events are counted, update the output.    
					if (VerboseUtil.countOpEvents(element, counter))
						updated = true; 													
				}
			}
		});
		
		parser.setElementHandler("concurrent-aborted", new VoidElementHandler() 
		{
			public void elementEnd(Element element) throws HierarchyException, ParseError 
			{
				synchronized (counter)
				{				
					counter.incrementAndGet(VerboseEvent.CONCURRENT_ABORTED.getSymbol());
					updated = true; 
				}
			}
		});
		
		parser.setElementHandler("warning", new VoidElementHandler() 
		{
			public void elementEnd(Element element) throws HierarchyException, ParseError 
			{
				synchronized (counter)
				{				
					VerboseUtil.countWarning(element, counter);
					updated = true; 
				}
			}
		});
			
		return parser; 
	}
}