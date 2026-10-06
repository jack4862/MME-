float3 vecA = normalize(float3( 0.0,           1.0, -pow(2.0,0.5)));
float3 vecB = normalize(float3(-pow(2.0,0.5), -1.0,  0.0         ));
float3 vecC = normalize(float3( 0.0,           1.0,  pow(2.0,0.5)));
float3 vecD = normalize(float3( pow(2.0,0.5), -1.0,  0.0         ));


#if 0

int ClipByDir( float3 eye, int dir )
{
	float EA = dot(normalize(eye),vecA);
	float EB = dot(normalize(eye),vecB);
	float EC = dot(normalize(eye),vecC);
	float ED = dot(normalize(eye),vecD);
	
	float d = 0.01; // ‹«ŠEü‘Îô
	//float d = -0.01; // ‹«ŠEü‚ğ•\¦
	
	if(dir == 0){
		if(EA<EB-d || EA<EC-d || EA<ED-d) return -1;
		else return 1;
	}else if(dir == 1){
		if(EB<EA-d || EB<EC-d || EB<ED-d) return -1;
		else return 1;
	}else if(dir == 2){
		if(EC<EA-d || EC<EB-d || EC<ED-d) return -1;
		else return 1;
	}else{
		if(ED<EA-d || ED<EB-d || ED<EC-d) return -1;
		else return 1;
	}
}

float4x4 ViewMatrixMaker( float3 CamPos, int dir )
{
	float4x4 cam = float4x4(float4(1,0,0,0),
	                        float4(0,1,0,0),
	                        float4(0,0,1,0),
	                        float4(-CamPos,1));
	float4x4 view;
	if(dir == 0){
		return mul(cam,float4x4(float4(1,0,0,0),
		                        float4(0,0.816496581,-0.577350269,0),
		                        float4(0,0.577350269,0.816496581,0),
		                        float4(0,0,0,1))); // z-
	}else if(dir == 1){
		return mul(cam,float4x4(float4(0,-0.577350269,0.816496581,0),
		                        float4(0,0.816496581,0.577350269,0),
		                        float4(-1,0,0,0),
		                        float4(0,0,0,1))); // x-
	}else if(dir == 2){
		return mul(cam,float4x4(float4(-1,0,0,0),
		                        float4(0,0.816496581,-0.577350269,0),
		                        float4(0,-0.577350269,-0.816496581,0),
		                        float4(0,0,0,1))); // z+
	}else{
		return mul(cam,float4x4(float4(0,0.577350269,-0.816496581,0),
		                        float4(0,0.816496581,0.577350269,0),
		                        float4(1,0,0,0),
		                        float4(0,0,0,1))); // x+
	}
}


float4x4 WVPMatrixMaker( float4x4 matW, float4x4 matP, float3 camPos, int dir )
{
	float4x4 wvp = mul(mul(matW,ViewMatrixMaker(camPos,dir)),matP);
	
	if(dir == 0){
		return mul(wvp,float4x4(float4(0.5,0,0,0),
		                        float4(-0.333333333,1.333333333,0,0),
		                        float4(0,0,1,0),
		                        float4(-0.666666667,-0.333333333,0,1)));
	}else if(dir == 1){
		return mul(wvp,float4x4(float4(0.5,0,0,0),
		                        float4(-0.333333333,1.333333333,0,0),
		                        float4(0,0,1,0),
		                        float4(-0.333333333,0.333333333,0,1)));
	}else if(dir ==2){
		return mul(wvp,float4x4(float4(0.5,0,0,0),
		                        float4(-0.333333333,1.333333333,0,0),
		                        float4(0,0,1,0),
		                        float4(0.333333333,-0.333333333,0,1)));
	}else{
		return mul(wvp,float4x4(float4(0.5,0,0,0),
		                        float4(-0.333333333,1.333333333,0,0),
		                        float4(0,0,1,0),
		                        float4(0.666666667,0.333333333,0,1)));
	}
}

#else

int ClipByDir( float3 eye, int dir )
{
	float3 vecA = normalize(float3( 0.0,           1.0, -pow(2.0,0.5)));
	float3 vecB = normalize(float3(-pow(2.0,0.5), -1.0,  0.0         ));
	float3 vecC = normalize(float3( 0.0,           1.0,  pow(2.0,0.5)));
	float3 vecD = normalize(float3( pow(2.0,0.5), -1.0,  0.0         ));
	
	float EA = dot(normalize(eye),vecA);
	float EB = dot(normalize(eye),vecB);
	float EC = dot(normalize(eye),vecC);
	float ED = dot(normalize(eye),vecD);
	
	float d = 0.01;
	//float d = -0.01; // ‚Æ‚·‚é‚Æ‹«ŠEü‚ğ•\¦‚Å‚«‚é
	
	/* switch‚¾‚Æ32bit‚Å‚¤‚Ü‚­“®‚©‚È‚¢ */
	if(dir == 0){
		return ( EA == max(EA,max(EB-d,max(EC-d,ED-d))) ) ? 1 : -1;
	}else if(dir == 1){
		return ( EB == max(EB,max(EA-d,max(EC-d,ED-d))) ) ? 1 : -1;
	}else if(dir == 2){
		return ( EC == max(EC,max(EA-d,max(EB-d,ED-d))) ) ? 1 : -1;
	}else{
		return ( ED == max(ED,max(EA-d,max(EB-d,EC-d))) ) ? 1 : -1;
	}
}



float4x4 ViewMatrixMaker( float3 CamPos, int dir )
{
	float4x4 cam = float4x4(
		float4(1,0,0,0),
		float4(0,1,0,0),
		float4(0,0,1,0),
		float4(-CamPos,1)
	);
	
	float4x4 vmat[4] = {
		{
			// z-
			{1,0,0,0},
			{0,0.816496581,-0.577350269,0},
			{0,0.577350269,0.816496581,0},
			{0,0,0,1}
		},
		{
			// x-
			{0,-0.577350269,0.816496581,0},
			{0,0.816496581,0.577350269,0},
			{-1,0,0,0},
			{0,0,0,1}
		},
		{
			// z+
			{-1,0,0,0},
			{0,0.816496581,-0.577350269,0},
			{0,-0.577350269,-0.816496581,0},
			{0,0,0,1}
		},
		{
			// x+
			{0,0.577350269,-0.816496581,0},
			{0,0.816496581,0.577350269,0},
			{1,0,0,0},
			{0,0,0,1}
		},
	};
	
	return mul(cam, vmat[dir]);
}

float4x4 WVPMatrixMaker( float4x4 matW, float4x4 matP, float3 camPos, int dir )
{
	float4x4 wvp = mul(mul(matW,ViewMatrixMaker(camPos,dir)),matP);
	
	float4x4 deform[4] = {
		{
			{0.5,0,0,0},
			{-0.333333333,1.333333333,0,0},
			{0,0,1,0},
			{-0.666666667,-0.333333333,0,1}
		},
		{
			{0.5,0,0,0},
			{-0.333333333,1.333333333,0,0},
			{0,0,1,0},
			{-0.333333333,0.333333333,0,1}
		},
		{
			{0.5,0,0,0},
			{-0.333333333,1.333333333,0,0},
			{0,0,1,0},
			{0.333333333,-0.333333333,0,1}
		},
		{
			{0.5,0,0,0},
			{-0.333333333,1.333333333,0,0},
			{0,0,1,0},
			{0.666666667,0.333333333,0,1}
		}
	};
	
	return mul(wvp, deform[dir]);
}

#endif