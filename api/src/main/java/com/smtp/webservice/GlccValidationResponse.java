package com.smtp.webservice;

import io.swagger.annotations.ApiModel;
import io.swagger.annotations.ApiModelProperty;

@ApiModel(description = "Represents all segments of a GL Code Combination")
public class GlccValidationResponse {
	private String client;
	private String responsibility;
	private String serviceLine;
	private String stob;
	private String project;

	
	public GlccValidationResponse(String Ccid) {
		if (Ccid.equals("010.000.000.000.000"))
		{
			client="010";
			responsibility="000";
			serviceLine="000";
			stob="000";
			project="000";
		}
		System.out.println("Insider Response Constructor");
	}
	
	@ApiModelProperty(value = "Client Segment", required = true)
	public String getClient() {
		return client;
	}
	public void setClient(String client) {
		this.client = client;
	}
	
	@ApiModelProperty(value = "Responsibility Segment", required = true)
	public String getResponsibility() {
		return responsibility;
	}
	public void setResponsibility(String responsibility) {
		this.responsibility = responsibility;
	}
	
	@ApiModelProperty(value = "Service Line Segment", required = true)
	public String getServiceLine() {
		return serviceLine;
	}
	public void setServiceLine(String serviceLine) {
		this.serviceLine = serviceLine;
	}
	
	@ApiModelProperty(value = "STOB Segment", required = true)
	public String getStob() {
		return stob;
	}
	public void setStob(String stob) {
		this.stob = stob;
	}
	
	@ApiModelProperty(value = "Project Segment", required = true)
	public String getProject() {
		return project;
	}
	public void setProject(String project) {
		this.project = project;
	}
}
