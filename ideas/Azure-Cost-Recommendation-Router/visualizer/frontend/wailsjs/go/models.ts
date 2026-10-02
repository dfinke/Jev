export namespace main {
	
	export class CSVInfo {
	    path: string;
	    recordCount: number;
	
	    static createFrom(source: any = {}) {
	        return new CSVInfo(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.path = source["path"];
	        this.recordCount = source["recordCount"];
	    }
	}

}

